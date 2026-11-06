import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../domain/curb_map.dart';
import 'map_style.dart';

/// Draws the coloured curb lines.
///
/// The [Polyline] list is built once per [CurbMap] and reused for every
/// frame while the user pans or zooms; only the painter runs per frame.
/// Lines are sorted by status, so neighbours share the same paint and
/// flutter_map can draw each colour as one batch.
class CurbLinesLayer extends StatefulWidget {
  const CurbLinesLayer({super.key, required this.curbMap});

  final CurbMap curbMap;

  @override
  State<CurbLinesLayer> createState() => _CurbLinesLayerState();
}

class _CurbLinesLayerState extends State<CurbLinesLayer> {
  late List<Polyline<int>> _lines = _build(widget.curbMap);

  @override
  void didUpdateWidget(CurbLinesLayer old) {
    super.didUpdateWidget(old);
    if (!identical(old.curbMap, widget.curbMap)) {
      _lines = _build(widget.curbMap);
    }
  }

  static List<Polyline<int>> _build(CurbMap map) {
    final segments = [...map.segments]
      ..sort((a, b) => MapStyle.drawOrder(a.status).compareTo(MapStyle.drawOrder(b.status)));
    return [
      for (final s in segments)
        Polyline<int>(
          points: [for (final p in s.points) LatLng(p.lat, p.lon)],
          color: MapStyle.colorOf(s.status),
          strokeWidth: MapStyle.curbWidth,
          borderStrokeWidth: MapStyle.curbCasingWidth,
          borderColor: MapStyle.curbCasing,
          hitValue: s.segmentId, // for "tap a curb" in the next step
        ),
    ];
  }

  @override
  Widget build(BuildContext context) => PolylineLayer<int>(
        polylines: _lines,
        // Skip lines more than 10 px outside the screen.
        cullingMargin: 10,
        // Montréal never crosses the antimeridian; draw one world only.
        drawInSingleWorld: true,
      );
}
