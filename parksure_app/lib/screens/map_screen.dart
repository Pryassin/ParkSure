import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../models/curb.dart';
import '../providers/parking_providers.dart';
import '../widgets/status_style.dart';
import '../widgets/verdict_sheet.dart';

/// The main page: the curb map, coloured by status. Tap a street to get the answer.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  static const _montreal = LatLng(45.5017, -73.5673);
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  /// Wait until the user stops panning before asking the API for the new area.
  void _onCameraMoved(MapCamera camera) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final b = camera.visibleBounds;
      ref.read(viewportProvider.notifier).set(MapBounds(b.west, b.south, b.east, b.north));
    });
  }

  @override
  Widget build(BuildContext context) {
    final curbMap = ref.watch(curbMapProvider);
    final view = ref.watch(viewportProvider);
    final pin = ref.watch(pinProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('ParkSure')),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: _montreal,
              initialZoom: 16,
              onPositionChanged: (camera, _) => _onCameraMoved(camera),
              onTap: (_, point) => ref
                  .read(pinProvider.notifier)
                  .set(PinQuery(lat: point.latitude, lon: point.longitude)),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.parksure.parksure',
              ),
              PolylineLayer(
                polylines: [
                  for (final curb in curbMap.value?.curbs ?? const <Curb>[])
                    for (final line in curb.lines)
                      Polyline(points: line, color: curb.status.color, strokeWidth: 5),
                ],
              ),
              if (pin != null)
                MarkerLayer(markers: [
                  Marker(
                    point: LatLng(pin.lat, pin.lon),
                    child: const Icon(Icons.location_pin, color: Colors.black87, size: 36),
                  ),
                ]),
            ],
          ),
          if (view?.tooWide ?? false) const _Banner('Zoom in to see parking rules'),
          if (curbMap.value?.truncated ?? false) const _Banner('Too many streets here — zoom in'),
          if (curbMap.hasError) const _Banner('Could not load the map rules'),
          if (curbMap.isLoading) const LinearProgressIndicator(),
          const Align(alignment: Alignment.bottomCenter, child: VerdictSheet()),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: Card(
          margin: const EdgeInsets.all(12),
          child: Padding(padding: const EdgeInsets.all(12), child: Text(text)),
        ),
      );
}
