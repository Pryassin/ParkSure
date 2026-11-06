import 'package:flutter/material.dart';

import '../theme/app_style.dart';

enum AppIconSize {
  small(AppStyle.iconSm),
  medium(AppStyle.iconMd);

  const AppIconSize(this.value);
  final double value;
}

/// An icon restricted to the app's sizes.
///
/// [color] is optional: when null the icon inherits its color from the
/// surrounding widget (e.g. a button's foreground color).
class AppIcon extends StatelessWidget {
  const AppIcon(
    this.icon, {
    super.key,
    this.size = AppIconSize.medium,
    this.color,
    this.semanticLabel,
  });

  final IconData icon;
  final AppIconSize size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Icon(
      icon,
      size: size.value,
      color: color,
      semanticLabel: semanticLabel,
    );
  }
}
