import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/parking_repository.dart';
import '../models/curb.dart';
import '../models/verdict.dart';

/// Override at build time: flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5277
const _apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:5277');

final parkingRepositoryProvider = Provider<ParkingRepository>(
  (ref) => ParkingRepository(baseUrl: _apiBaseUrl),
);

// ------------------------------------------------------------------ user settings

/// The user's SRR permit zone (one per user in v1). Null = no permit.
class PermitNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? zone) => state = (zone == null || zone.trim().isEmpty) ? null : zone.trim();
}

final permitProvider = NotifierProvider<PermitNotifier, String?>(PermitNotifier.new);

/// The time being checked. Null = "now".
class QueryTimeNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;
  void set(DateTime? t) => state = t;
}

final queryTimeProvider = NotifierProvider<QueryTimeNotifier, DateTime?>(QueryTimeNotifier.new);

// ------------------------------------------------------------------ map

/// A viewport in degrees.
class MapBounds {
  const MapBounds(this.minLon, this.minLat, this.maxLon, this.maxLat);
  final double minLon, minLat, maxLon, maxLat;

  bool get tooWide =>
      (maxLon - minLon) > ParkingRepository.maxLonSpan || (maxLat - minLat) > ParkingRepository.maxLatSpan;

  @override
  bool operator ==(Object other) =>
      other is MapBounds &&
      other.minLon == minLon &&
      other.minLat == minLat &&
      other.maxLon == maxLon &&
      other.maxLat == maxLat;

  @override
  int get hashCode => Object.hash(minLon, minLat, maxLon, maxLat);
}

class ViewportNotifier extends Notifier<MapBounds?> {
  @override
  MapBounds? build() => null;
  void set(MapBounds v) => state = v;
}

final viewportProvider = NotifierProvider<ViewportNotifier, MapBounds?>(ViewportNotifier.new);

/// Curbs for the current viewport. Null data = zoomed out too far (nothing requested).
final curbMapProvider = FutureProvider<CurbMap?>((ref) async {
  final view = ref.watch(viewportProvider);
  if (view == null || view.tooWide) return null;
  return ref.read(parkingRepositoryProvider).curbsInView(
        minLon: view.minLon,
        minLat: view.minLat,
        maxLon: view.maxLon,
        maxLat: view.maxLat,
        at: ref.watch(queryTimeProvider),
        permit: ref.watch(permitProvider),
      );
});

// ------------------------------------------------------------------ point check

/// A point the user asked about. [segmentId] is set once they pick a side of an ambiguous tap.
class PinQuery {
  const PinQuery({required this.lat, required this.lon, this.mode = 'tap', this.segmentId});
  final double lat, lon;
  final String mode;
  final int? segmentId;

  @override
  bool operator ==(Object other) =>
      other is PinQuery && other.lat == lat && other.lon == lon && other.mode == mode && other.segmentId == segmentId;

  @override
  int get hashCode => Object.hash(lat, lon, mode, segmentId);
}

class PinNotifier extends Notifier<PinQuery?> {
  @override
  PinQuery? build() => null;
  void set(PinQuery? q) => state = q;
}

final pinProvider = NotifierProvider<PinNotifier, PinQuery?>(PinNotifier.new);

/// The verdict for the current pin. Null data = no pin dropped.
final verdictProvider = FutureProvider<Verdict?>((ref) async {
  final pin = ref.watch(pinProvider);
  if (pin == null) return null;
  return ref.read(parkingRepositoryProvider).checkAt(
        lat: pin.lat,
        lon: pin.lon,
        mode: pin.mode,
        segmentId: pin.segmentId,
        at: ref.watch(queryTimeProvider),
        permit: ref.watch(permitProvider),
      );
});
