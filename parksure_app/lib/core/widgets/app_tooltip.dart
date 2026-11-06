import 'package:flutter/material.dart';

import '../theme/app_style.dart';

/// A tooltip styled for ParkSure: black pill with small white text.
class AppTooltip extends StatelessWidget {
  const AppTooltip({super.key, required this.message, required this.child});

  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: message,
      waitDuration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.symmetric(
        horizontal: AppStyle.spaceSm,
        vertical: AppStyle.spaceXs,
      ),
      decoration: BoxDecoration(
        color: AppStyle.black,
        borderRadius: BorderRadius.circular(AppStyle.radiusSm),
      ),
      textStyle: AppStyle.small.copyWith(color: AppStyle.white),
      child: child,
    );
  }
}
