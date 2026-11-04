import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/curb.dart';
import '../models/verdict.dart';

/// Thrown when the API answers with an error or can't be reached.
class ParkingApiException implements Exception {
  ParkingApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => 'ParkingApiException($statusCode): $message';
}

/// The only place the app talks to the ParkSure API.
class ParkingRepository {
  ParkingRepository({required this.baseUrl, http.Client? client}) : _client = client ?? http.Client();

  /// e.g. http://10.0.2.2:5277 on the Android emulator, http://localhost:5277 on iOS simulator.
  final String baseUrl;
  final http.Client _client;

  /// Max viewport the backend accepts (see BoundingBox in ParkSure.Repositories).
  static const maxLonSpan = 0.07;
  static const maxLatSpan = 0.05;

  /// `GET /api/curbs/at` — the answer for one point (a tap or a GPS check).
  Future<Verdict> checkAt({
    required double lat,
    required double lon,
    String mode = 'tap',
    int? segmentId,
    DateTime? at,
    String? permit,
  }) async {
    final json = await _get('/api/curbs/at', {
      'lat': '$lat',
      'lon': '$lon',
      'mode': mode,
      if (segmentId != null) 'segmentId': '$segmentId',
      if (at != null) 'at': _iso(at),
      if (permit != null && permit.isNotEmpty) 'permit': permit,
    });
    return Verdict.fromJson(json);
  }

  /// `GET /api/curbs?bbox=` — every curb side in the visible map area.
  Future<CurbMap> curbsInView({
    required double minLon,
    required double minLat,
    required double maxLon,
    required double maxLat,
    DateTime? at,
    String? permit,
  }) async {
    final json = await _get('/api/curbs', {
      'bbox': '$minLon,$minLat,$maxLon,$maxLat',
      if (at != null) 'at': _iso(at),
      if (permit != null && permit.isNotEmpty) 'permit': permit,
    });
    return CurbMap.fromJson(json);
  }

  /// The backend requires an explicit offset; UTC with a trailing Z satisfies it.
  static String _iso(DateTime t) => t.toUtc().toIso8601String();

  Future<Map<String, dynamic>> _get(String path, Map<String, String> query) async {
    final uri = Uri.parse(baseUrl).replace(path: path, queryParameters: query);
    final http.Response res;
    try {
      res = await _client.get(uri, headers: {'Accept': 'application/json'});
    } catch (e) {
      throw ParkingApiException('Could not reach the server: $e');
    }
    if (res.statusCode != 200) {
      String message = 'HTTP ${res.statusCode}';
      try {
        message = (jsonDecode(res.body) as Map<String, dynamic>)['error'] as String? ?? message;
      } catch (_) {}
      throw ParkingApiException(message, statusCode: res.statusCode);
    }
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }
}
