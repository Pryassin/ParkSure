import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../../core/api/parksure_api.dart';
import '../../../core/domain/curb_status.dart';
import '../../../core/domain/geo_bounds.dart';
import '../../../core/widgets/widgets.dart';
import 'curb_lines_layer.dart';
import 'curb_map_controller.dart';
import 'map_style.dart';

/// The home screen: a pale map of Montréal with every curb coloured by
/// whether you can park there now (UX Pilot "ParkSure - Map").
class MapScreen extends StatefulWidget {
  const MapScreen({super.key, this.api, this.showBaseMap = true});

  /// Injected in tests; a real client otherwise.
  final ParkSureApi? api;

  /// Tests turn the tile layer off so they do not hit the network.
  final bool showBaseMap;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _mapController = MapController();
  late final ParkSureApi _api = widget.api ?? ParkSureApi();
  late final _curbs = CurbMapController(api: _api);

  @override
  void dispose() {
    _curbs.dispose();
    if (widget.api == null) _api.close();
    _mapController.dispose();
    super.dispose();
  }

  void _onCameraChanged(MapCamera camera) {
    final b = camera.visibleBounds;
    _curbs.onViewportChanged(
      GeoBounds(minLon: b.west, minLat: b.south, maxLon: b.east, maxLat: b.north),
      camera.zoom,
    );
  }

  void _recenter() =>
      _mapController.move(MapStyle.initialCenter, MapStyle.initialZoom);

  @override
  Widget build(BuildContext context) {
    // Dark status-bar icons over the light map.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: MapStyle.background,
        body: Stack(
          children: [
            Positioned.fill(child: _buildMap(context)),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppStyle.spaceMd, AppStyle.spaceSm, AppStyle.spaceMd, 0),
                child: Column(
                  children: [
                    const RepaintBoundary(child: _TopBar()),
                    const SizedBox(height: AppStyle.spaceSm),
                    ListenableBuilder(
                      listenable: _curbs,
                      builder: (context, _) => _ProblemBanner(controller: _curbs),
                    ),
                  ],
                ),
              ),
            ),
            ListenableBuilder(
              listenable: _curbs,
              builder: (context, _) => _curbs.problem == MapProblem.zoomIn
                  ? const Center(child: _ZoomInPill())
                  : const SizedBox.shrink(),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: RepaintBoundary(
                child: _BottomBar(controller: _curbs, onRecenter: _recenter),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap(BuildContext context) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: MapStyle.initialCenter,
        initialZoom: MapStyle.initialZoom,
        minZoom: MapStyle.minZoom,
        maxZoom: MapStyle.maxZoom,
        backgroundColor: MapStyle.background,
        cameraConstraint: CameraConstraint.containCenter(bounds: MapStyle.montreal),
        // No rotation: north-up keeps street names and the bbox simple.
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onMapReady: () => _onCameraChanged(_mapController.camera),
        onPositionChanged: (camera, _) => _onCameraChanged(camera),
      ),
      children: [
        if (widget.showBaseMap)
          TileLayer(
            urlTemplate: MapStyle.tileUrl,
            tileDimension: MapStyle.tileDimension,
            zoomOffset: MapStyle.tileZoomOffset,
            maxNativeZoom: MapStyle.maxNativeZoom,
            maxZoom: MapStyle.maxZoom,
            userAgentPackageName: MapStyle.userAgentPackageName,
            // Load one ring of tiles past the screen edge before it is
            // needed, keep two rings after; a short fade avoids pop-in.
            panBuffer: 1,
            keepBuffer: 3,
            tileDisplay: const TileDisplay.fadeIn(duration: Duration(milliseconds: 120)),
          ),
        ListenableBuilder(
          listenable: _curbs,
          builder: (context, _) {
            final map = _curbs.curbMap;
            return _curbs.showsCurbs && map != null
                ? CurbLinesLayer(curbMap: map)
                : const SizedBox.shrink();
          },
        ),
      ],
    );
  }
}

// ───────────────────────────── Top bar ─────────────────────────────

/// "P ParkSure | Now ⌄ | Permit ⌄". Now and Permit open their sheets in a
/// later step.
class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return _FloatingCard(
      height: AppStyle.topBarHeight,
      radius: AppStyle.radiusPill,
      padding: const EdgeInsets.symmetric(horizontal: AppStyle.spaceSm + 2),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppStyle.black,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('P',
                style: TextStyle(color: AppStyle.white, fontSize: 13, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: AppStyle.spaceSm),
          // Shrinks first, so Now / Permit always fit (large text sizes).
          const Expanded(
            child: Text('ParkSure',
                style: AppStyle.bodyBold, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const _Divider(),
          const _TopBarChip(label: 'Now'),
          const _Divider(),
          const _TopBarChip(label: 'Permit'),
        ],
      ),
    );
  }
}

class _TopBarChip extends StatelessWidget {
  const _TopBarChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppStyle.spaceSm + 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: AppStyle.body),
          const SizedBox(width: 2),
          const Icon(AppIcons.chevronDown, size: AppStyle.iconSm + 2, color: AppStyle.textPrimary),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 20, color: AppStyle.border);
}

// ─────────────────────────── States ───────────────────────────

/// StateNetwork / error: "Can't reach ParkSure. Last update 09:12 · Retry".
class _ProblemBanner extends StatelessWidget {
  const _ProblemBanner({required this.controller});

  final CurbMapController controller;

  @override
  Widget build(BuildContext context) {
    final problem = controller.problem;
    if (problem != MapProblem.offline && problem != MapProblem.error) {
      return const SizedBox.shrink();
    }

    final updated = controller.lastUpdated;
    final text = problem == MapProblem.offline
        ? "Can't reach ParkSure."
            '${updated == null ? '' : ' Last update ${_hhmm(updated)}'}'
        : controller.errorMessage ?? 'Something went wrong.';

    return _FloatingCard(
      radius: AppStyle.radiusPill,
      padding: const EdgeInsets.fromLTRB(AppStyle.spaceMd, 6, 6, 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(color: AppStyle.error, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppStyle.spaceSm),
          Flexible(child: Text(text, style: AppStyle.caption.copyWith(color: AppStyle.textPrimary))),
          TextButton(
            onPressed: controller.isLoading ? null : controller.refresh,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: AppStyle.spaceSm),
              foregroundColor: AppStyle.textPrimary,
              textStyle: AppStyle.caption.copyWith(
                  fontWeight: FontWeight.w600, decoration: TextDecoration.underline),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  static String _hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

/// StateZoom: "Zoom in to see curb rules".
class _ZoomInPill extends StatelessWidget {
  const _ZoomInPill();

  @override
  Widget build(BuildContext context) {
    return _FloatingCard(
      radius: AppStyle.radiusPill,
      padding: const EdgeInsets.symmetric(horizontal: AppStyle.spaceMd, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(AppIcons.zoomIn, size: AppStyle.iconSm, color: AppStyle.textSecondary),
          const SizedBox(width: 6),
          Text('Zoom in to see curb rules',
              style: AppStyle.caption.copyWith(color: AppStyle.textPrimary)),
        ],
      ),
    );
  }
}

// ─────────────────────────── Bottom bar ───────────────────────────

/// "Tap a curb to check it" and the legend: one count per status, for the
/// curbs currently on screen.
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.controller, required this.onRecenter});

  final CurbMapController controller;
  final VoidCallback onRecenter;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppStyle.spaceMd),
          child: AppIconButton(
            icon: AppIcons.locate,
            tooltip: 'Back to the start',
            onPressed: onRecenter,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: AppStyle.spaceMd, bottom: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(MapStyle.attribution,
                style: AppStyle.small.copyWith(fontSize: 9, color: AppStyle.textMuted)),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppStyle.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppStyle.radiusLg)),
            border: const Border(top: BorderSide(color: AppStyle.border)),
            boxShadow: [
              BoxShadow(
                color: AppStyle.black.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                AppStyle.spaceMd + 4, 0, AppStyle.spaceMd + 4, AppStyle.spaceMd + bottomInset),
            child: ListenableBuilder(
              listenable: controller,
              builder: (context, _) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Grab handle; doubles as a hairline loading bar.
                  SizedBox(
                    height: 20,
                    child: Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: SizedBox(
                          width: 36,
                          height: 4,
                          child: controller.isLoading
                              ? const LinearProgressIndicator(
                                  backgroundColor: AppStyle.border,
                                  color: AppStyle.textSecondary,
                                )
                              : const ColoredBox(color: AppStyle.border),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Tap a curb to check it',
                            style: AppStyle.body, overflow: TextOverflow.ellipsis),
                      ),
                      _Legend(counts: controller.visibleCounts),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.counts});

  final Map<CurbStatus, int> counts;

  static const _order = [
    (CurbStatus.allowed, 'allowed'),
    (CurbStatus.conditions, 'with conditions'),
    (CurbStatus.notAllowed, 'not allowed'),
    (CurbStatus.unknown, 'unknown'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (status, name) in _order)
          Semantics(
            label: '${counts[status]} $name',
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 3,
                    decoration: BoxDecoration(
                      color: MapStyle.colorOf(status),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text('${counts[status]}',
                      style: AppStyle.caption.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()])),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────── Shared ───────────────────────────

/// White card floating over the map with a soft shadow.
class _FloatingCard extends StatelessWidget {
  const _FloatingCard({
    required this.child,
    required this.radius,
    this.padding = EdgeInsets.zero,
    this.height,
  });

  final Widget child;
  final double radius;
  final EdgeInsets padding;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: AppStyle.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppStyle.border),
        boxShadow: [
          BoxShadow(
            color: AppStyle.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
