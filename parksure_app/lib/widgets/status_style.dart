import 'package:flutter/material.dart';

import '../models/verdict.dart';

/// One place that decides how each status looks.
extension StatusStyle on ParkingStatus {
  Color get color => switch (this) {
        ParkingStatus.allowed => const Color(0xFF2E7D32),
        ParkingStatus.conditions => const Color(0xFFF9A825),
        ParkingStatus.notAllowed => const Color(0xFFC62828),
        ParkingStatus.unknown => const Color(0xFF9E9E9E),
      };

  String get label => switch (this) {
        ParkingStatus.allowed => 'Allowed',
        ParkingStatus.conditions => 'Conditions',
        ParkingStatus.notAllowed => 'Not allowed',
        ParkingStatus.unknown => 'Unknown',
      };

  IconData get icon => switch (this) {
        ParkingStatus.allowed => Icons.check_circle,
        ParkingStatus.conditions => Icons.schedule,
        ParkingStatus.notAllowed => Icons.block,
        ParkingStatus.unknown => Icons.help_outline,
      };
}
