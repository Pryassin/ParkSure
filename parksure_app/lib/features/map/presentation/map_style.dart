import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/domain/curb_status.dart';
import '../../../core/theme/app_style.dart';

/// Everything about how the map looks, in one place.
abstract final class MapStyle {
  // ───────────────────────── Base map ─────────────────────────

  /// Base-map tiles: Esri "Light Gray", a pale, low-detail style with
  /// streets and labels only, so the coloured curbs are the only strong
  /// colour on screen (matches the UX Pilot Map screen).
  ///
  /// * **With a token** (release builds): ArcGIS Location Platform static
  ///   basemap tiles. Licensed for commercial apps, detail up to zoom 22.
  ///   Create the token at location.arcgis.com, then put it in `env.json`
  ///   (git-ignored, see `env.example.json`) and build with:
  ///     flutter run --dart-define-from-file=env.json
  /// * **Without a token** (development only, do not ship): the legacy
  ///   keyless "World Light Gray Canvas" service. Same look, but real tiles
  ///   only up to zoom 16 here, so closer zooms are stretched.
  ///
  /// (CARTO Positron, used before, now serves an "API KEY REQUIRED" image
  /// for every tile without a key.)
  ///
  /// The token ships inside the app, where it can be extracted: keep
  /// pay-as-you-go off or capped in the ArcGIS account.
  static const String _arcgisToken = String.fromEnvironment('ARCGIS_TOKEN');
  static const bool hasLicensedTiles = _arcgisToken != '';

  // Both are ArcGIS tile services: note the {y}/{x} order.
  static const String tileUrl = hasLicensedTiles
      ? 'https://static-map-tiles-api.arcgis.com/arcgis/rest/services/static-basemap-tiles-service/v1/arcgis/light-gray/static/tile/{z}/{y}/{x}?token=$_arcgisToken'
      : 'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Base/MapServer/tile/{z}/{y}/{x}';

  /// Esri requires "Powered by Esri" plus the data sources.
  static const String attribution = hasLicensedTiles
      ? 'Powered by Esri · © Esri, TomTom, Garmin, © OpenStreetMap contributors'
      : '© Esri, HERE, Garmin · © OpenStreetMap contributors';

  /// The licensed tiles are 512 px with labels sized for 512, like Mapbox
  /// tiles: shown at 512 with a -1 zoom offset (as in Esri's own examples),
  /// otherwise street names come out at half size. The legacy service is the
  /// classic 256 px.
  static const int tileDimension = hasLicensedTiles ? 512 : 256;
  static const double tileZoomOffset = hasLicensedTiles ? -1 : 0;

  /// Sent as the User-Agent so tile servers can identify the app.
  static const String userAgentPackageName = 'com.parksure.parksure_app';

  /// Shown before tiles arrive; the same off-white as Positron's land, so
  /// there is no black or grey flash while panning.
  static const Color background = Color(0xFFFAFAF8);

  /// Deepest tile zoom the server has real detail for. Licensed tiles go to
  /// 22. The legacy service has real tiles only up to 16 around Montréal;
  /// above that it serves a "Map data not yet available" image, so closer
  /// zooms stretch the zoom-16 tiles instead.
  static const int maxNativeZoom = hasLicensedTiles ? 22 : 16;
  static const double maxZoom = 20;
  static const double minZoom = 11;

  // ───────────────────────── Camera ─────────────────────────

  /// Plateau-Mont-Royal (Rue Rivard / Avenue du Mont-Royal).
  static const LatLng initialCenter = LatLng(45.5236, -73.5810);
  static const double initialZoom = 17;

  /// The Island of Montréal plus a margin. The camera centre cannot leave
  /// it: there is no parking data anywhere else.
  static final LatLngBounds montreal = LatLngBounds(
    const LatLng(45.38, -74.00),
    const LatLng(45.72, -73.45),
  );

  // ───────────────────────── Curbs ─────────────────────────

  static const double curbWidth = AppStyle.curbStrokeWidth;

  /// A thin white edge so lines stay readable over grey streets and labels.
  static const double curbCasingWidth = 1;
  static const Color curbCasing = Color(0xE6FFFFFF);

  static Color colorOf(CurbStatus status) => switch (status) {
        CurbStatus.allowed => AppStyle.allowed,
        CurbStatus.conditions => AppStyle.conditions,
        CurbStatus.notAllowed => AppStyle.notAllowed,
        CurbStatus.unknown => AppStyle.unknown,
      };

  /// Drawing order, bottom to top. Where two curbs overlap (zoomed out, or
  /// both sides of a narrow street) the stricter one is drawn on top: the
  /// map follows the same "strictest wins" rule as the verdict.
  static int drawOrder(CurbStatus status) => switch (status) {
        CurbStatus.unknown => 0,
        CurbStatus.allowed => 1,
        CurbStatus.conditions => 2,
        CurbStatus.notAllowed => 3,
      };
}
