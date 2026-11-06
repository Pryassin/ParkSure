import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../features/map/data/curb_map_json.dart';
import '../../features/map/domain/curb_map.dart';
import '../../features/verdict/data/curb_answer_json.dart';
import '../../features/verdict/domain/curb_answer.dart';
import '../domain/geo_bounds.dart';
import '../domain/geo_point.dart';
import 'api_config.dart';
import 'api_exception.dart';

/// How the point was chosen. GPS always picks the nearest curb; a tap between
/// two curbs can come back as [PickSide].
enum PinMode { gps, tap }

/// The ParkSure backend. Every method either returns a domain object or
/// throws an [ApiException]; callers never see raw HTTP or JSON.
class ParkSureApi {
  ParkSureApi({http.Client? client, Uri? baseUrl, this.timeout = _defaultTimeout})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  static const _defaultTimeout = Duration(seconds: 10);

  final http.Client _client;
  final Uri _baseUrl;
  final Duration timeout;

  /// Every curb in [bounds], coloured for [at] (default: now).
  ///
  /// Throws [ApiErrorKind.tooLarge] when the area is too big; the map should
  /// ask the user to zoom in.
  Future<CurbMap> getMap(GeoBounds bounds, {DateTime? at, String? permit}) async {
    final json = await _get('/api/curbs', {
      'bbox': bounds.toQuery(),
      'at': ?_time(at),
      'permit': ?_permit(permit),
    });
    return _parse(() => curbMapFromJson(json));
  }

  /// "Can I park here?" for one point.
  ///
  /// Pass [segmentId] after the user picked a side from a [PickSide] answer.
  Future<CurbAnswer> getAnswer(
    GeoPoint point, {
    PinMode mode = PinMode.gps,
    int? segmentId,
    DateTime? at,
    String? permit,
  }) async {
    final json = await _get('/api/curbs/at', {
      'lat': '${point.lat}',
      'lon': '${point.lon}',
      'mode': mode.name,
      'segmentId': ?segmentId?.toString(),
      'at': ?_time(at),
      'permit': ?_permit(permit),
    });
    return _parse(() => curbAnswerFromJson(json));
  }

  void close() => _client.close();

  // ------------------------------------------------------------------ helpers

  /// The API needs an explicit offset; UTC with `Z` is the simplest.
  static String? _time(DateTime? at) => at?.toUtc().toIso8601String();

  static String? _permit(String? permit) {
    final trimmed = permit?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  Future<Map<String, dynamic>> _get(String path, Map<String, String> query) async {
    final uri = _baseUrl.replace(path: path, queryParameters: query);

    final http.Response response;
    try {
      response = await _client.get(uri).timeout(timeout);
    } on TimeoutException {
      throw const ApiException(ApiErrorKind.network, 'The server took too long to answer');
    } on http.ClientException catch (e) {
      throw ApiException(ApiErrorKind.network, 'Could not reach the server: ${e.message}');
    }

    final body = _decode(response);
    if (response.statusCode == 200 && body != null) return body;

    final message = body?['error'] as String? ?? 'HTTP ${response.statusCode}';
    final kind = switch (response.statusCode) {
      400 when message.contains('too large') => ApiErrorKind.tooLarge,
      400 => ApiErrorKind.badRequest,
      404 => ApiErrorKind.notFound,
      _ => ApiErrorKind.server,
    };
    throw ApiException(kind, message, statusCode: response.statusCode);
  }

  /// A 200 with a body we cannot read is a server problem, not a crash.
  static T _parse<T>(T Function() parse) {
    try {
      return parse();
    } on Object catch (e) {
      if (e is! TypeError && e is! FormatException) rethrow;
      throw ApiException(ApiErrorKind.server, 'Unexpected response from the server: $e');
    }
  }

  static Map<String, dynamic>? _decode(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }
}
