/// Why a call to the ParkSure API failed. Each kind maps to a screen state:
///
/// * [ApiErrorKind.network]  → "No connection" (StateNetwork)
/// * [ApiErrorKind.tooLarge] → "Zoom in to see curbs" (StateZoom)
/// * [ApiErrorKind.notFound] → the curb no longer exists
/// * [ApiErrorKind.badRequest] / [ApiErrorKind.server] → generic error
enum ApiErrorKind { network, badRequest, tooLarge, notFound, server }

class ApiException implements Exception {
  const ApiException(this.kind, this.message, {this.statusCode});

  final ApiErrorKind kind;

  /// The API's own message (`{"error": "..."}`) when it sent one.
  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException($kind, $statusCode): $message';
}
