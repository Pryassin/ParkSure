import 'package:flutter/foundation.dart';

/// Where the ParkSure API lives.
///
/// Override at build time:
///   flutter run --dart-define=API_BASE_URL=https://api.example.com
///
/// Defaults (local development, API on port 5277):
/// * Android emulator → http://10.0.2.2:5277 (the emulator's alias for the
///   host machine; `localhost` would be the emulator itself)
/// * everything else  → http://localhost:5277
class ApiConfig {
  const ApiConfig._();

  static const _override = String.fromEnvironment('API_BASE_URL');

  static Uri get baseUrl {
    if (_override.isNotEmpty) return Uri.parse(_override);
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return Uri.parse('http://10.0.2.2:5277');
    }
    return Uri.parse('http://localhost:5277');
  }
}
