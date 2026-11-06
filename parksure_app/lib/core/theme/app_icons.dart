import 'package:flutter/material.dart';

/// Every icon the app uses, named by meaning instead of by shape.
///
/// Widgets ask for `AppIcons.locate`, never `Icons.my_location`, so swapping
/// an icon (or the whole icon set) is a one-line change here.
abstract final class AppIcons {
  static const IconData locate = Icons.my_location_rounded;
  static const IconData chevronDown = Icons.keyboard_arrow_down_rounded;
  static const IconData chevronUp = Icons.keyboard_arrow_up_rounded;
  static const IconData check = Icons.check_rounded;
  static const IconData close = Icons.close_rounded;
  static const IconData info = Icons.info_outline_rounded;
  static const IconData time = Icons.schedule_rounded;
  static const IconData permit = Icons.badge_outlined;
  static const IconData offline = Icons.cloud_off_rounded;
  static const IconData zoomIn = Icons.zoom_in_rounded;
}
