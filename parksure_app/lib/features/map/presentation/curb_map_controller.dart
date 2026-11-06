import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/parksure_api.dart';
import '../../../core/domain/curb_status.dart';
import '../../../core/domain/geo_bounds.dart';
import '../domain/curb_map.dart';

/// Something that keeps the map from showing fresh curbs.
enum MapProblem {
  /// Zoomed out too far: curbs are hidden and no request is sent.
  zoomIn,

  /// The server could not be reached. The last curbs stay on screen.
  offline,

  /// Any other failure. The last curbs stay on screen.
  error,
}

/// Decides when to load curbs as the user moves the map.
///
/// Speed comes from loading less often, not from loading faster:
///
/// 1. **Prefetch.** Each request covers the visible area plus half a screen
///    on every side (2× wider and taller). Small pans stay inside it and send
///    no request at all.
/// 2. **Debounce.** While a finger is moving, requests wait [debounce]. A
///    fling sends one request where it stops, not one per frame.
/// 3. **Latest wins.** Every request has a number; a slow answer for an old
///    position is thrown away instead of overwriting a newer one.
/// 4. **Zoom gate.** Below [minCurbZoom] the curbs are too small to read, so
///    nothing is requested.
/// 5. **Keep what you have.** While loading, or when offline, the previous
///    curbs stay visible: the map never flashes empty.
///
/// It has no Flutter widgets in it, so it can be tested without a screen.
class CurbMapController extends ChangeNotifier {
  CurbMapController({
    required this.api,
    this.debounce = const Duration(milliseconds: 150),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// Below this zoom the app asks the user to zoom in (StateZoom).
  static const double minCurbZoom = 15;

  /// The API refuses boxes larger than this (BoundingBox.MaxSpanLon/Lat).
  static const double maxSpanLon = 0.07;
  static const double maxSpanLat = 0.05;

  /// How much extra area to load around the screen, per side.
  static const double prefetch = 0.5;

  final ParkSureApi api;
  final DateTime Function() _clock;
  final Duration debounce;

  /// The curbs on screen. Kept while reloading or offline.
  CurbMap? get curbMap => _curbMap;
  CurbMap? _curbMap;

  bool get isLoading => _isLoading;
  bool _isLoading = false;

  MapProblem? get problem => _problem;
  MapProblem? _problem;

  /// The server's message for [MapProblem.error].
  String? get errorMessage => _errorMessage;
  String? _errorMessage;

  /// When the curbs on screen were loaded ("Last update 09:12").
  DateTime? get lastUpdated => _lastUpdated;
  DateTime? _lastUpdated;

  /// Curbs per status inside the visible area (not the prefetched area),
  /// for the legend.
  Map<CurbStatus, int> get visibleCounts => _visibleCounts;
  Map<CurbStatus, int> _visibleCounts = _zeroCounts();

  /// True when curbs should be drawn.
  bool get showsCurbs => _problem != MapProblem.zoomIn && _curbMap != null;

  GeoBounds? _visible;
  GeoBounds? _loadedArea;
  int _latestRequest = 0;
  Timer? _loadTimer;
  Timer? _expiryTimer;
  bool _disposed = false;

  /// Call on every camera change. Cheap: most calls return immediately.
  void onViewportChanged(GeoBounds visible, double zoom) {
    _visible = visible;

    final tooFar = zoom < minCurbZoom ||
        visible.widthLon > maxSpanLon ||
        visible.heightLat > maxSpanLat;
    if (tooFar) {
      _loadTimer?.cancel();
      _latestRequest++; // ignore anything still in flight
      _isLoading = false;
      _set(MapProblem.zoomIn);
      return;
    }
    if (_problem == MapProblem.zoomIn) _set(null);

    if (_loadedArea?.containsBounds(visible) ?? false) {
      _scheduleLoad(countsOnly: true);
      return;
    }
    _scheduleLoad();
  }

  /// Reload now, e.g. from a "Retry" button.
  Future<void> refresh() {
    _loadTimer?.cancel();
    _loadedArea = null;
    return _load();
  }

  void _scheduleLoad({bool countsOnly = false}) {
    _loadTimer?.cancel();
    _loadTimer = Timer(debounce, countsOnly ? _updateCounts : _load);
  }

  Future<void> _load() async {
    final visible = _visible;
    if (visible == null || _disposed) return;

    final area = visible.expanded(
      prefetch,
      maxWidthLon: maxSpanLon,
      maxHeightLat: maxSpanLat,
    );
    final request = ++_latestRequest;
    _isLoading = true;
    notifyListeners();

    try {
      final map = await api.getMap(area);
      if (request != _latestRequest || _disposed) return; // a newer one won
      _curbMap = map;
      _loadedArea = area;
      _lastUpdated = _clock();
      _problem = null;
      _errorMessage = null;
      _visibleCounts = _countInside(visible);
      _scheduleExpiry(map);
    } on ApiException catch (e) {
      if (request != _latestRequest || _disposed) return;
      _problem = switch (e.kind) {
        ApiErrorKind.network => MapProblem.offline,
        ApiErrorKind.tooLarge => MapProblem.zoomIn,
        _ => MapProblem.error,
      };
      _errorMessage = e.message;
    } finally {
      if (request == _latestRequest && !_disposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Colours change on their own (a ban starts at 10:00). Reload just after
  /// the first curb on screen changes status, so the map is never stale.
  void _scheduleExpiry(CurbMap map) {
    _expiryTimer?.cancel();
    final now = _clock();
    DateTime? next;
    for (final segment in map.segments) {
      final until = segment.validUntil;
      if (until != null && until.isAfter(now) && (next == null || until.isBefore(next))) {
        next = until;
      }
    }
    if (next == null) return;
    final wait = next.difference(now) + const Duration(seconds: 1);
    if (wait > const Duration(hours: 12)) return; // the app will have reloaded by then
    _expiryTimer = Timer(wait, refresh);
  }

  void _updateCounts() {
    final visible = _visible;
    if (visible == null || _disposed) return;
    _visibleCounts = _countInside(visible);
    notifyListeners();
  }

  /// Counts a curb as visible when any of its points is on screen.
  Map<CurbStatus, int> _countInside(GeoBounds visible) {
    final counts = _zeroCounts();
    for (final segment in _curbMap?.segments ?? const []) {
      final onScreen = segment.points.any((p) =>
          p.lon >= visible.minLon &&
          p.lon <= visible.maxLon &&
          p.lat >= visible.minLat &&
          p.lat <= visible.maxLat);
      if (onScreen) counts[segment.status] = counts[segment.status]! + 1;
    }
    return counts;
  }

  void _set(MapProblem? problem) {
    if (_problem == problem) return;
    _problem = problem;
    notifyListeners();
  }

  static Map<CurbStatus, int> _zeroCounts() =>
      {for (final status in CurbStatus.values) status: 0};

  @override
  void dispose() {
    _disposed = true;
    _loadTimer?.cancel();
    _expiryTimer?.cancel();
    super.dispose();
  }
}
