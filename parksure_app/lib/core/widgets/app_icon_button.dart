import 'package:flutter/material.dart';

import '../theme/app_style.dart';
import 'app_icon.dart';
import 'app_tooltip.dart';

enum AppIconButtonVariant {
  /// Black circle, white icon.
  filled,

  /// White circle with a shadow, floating over the map (locate button).
  floating,

  /// Icon only, no background.
  plain,
}

/// A round icon button.
///
/// [tooltip] is required: an icon alone does not say what it does, and the
/// same text is read out by screen readers.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.variant = AppIconButtonVariant.floating,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final AppIconButtonVariant variant;

  static const double _size = 44;

  @override
  Widget build(BuildContext context) {
    final (background, foreground, elevation) = switch (variant) {
      AppIconButtonVariant.filled => (AppStyle.black, AppStyle.white, 0.0),
      AppIconButtonVariant.floating => (AppStyle.white, AppStyle.textPrimary, 2.0),
      AppIconButtonVariant.plain => (Colors.transparent, AppStyle.textPrimary, 0.0),
    };

    return AppTooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        icon: AppIcon(icon, semanticLabel: tooltip),
        style: IconButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          disabledForegroundColor: AppStyle.textMuted,
          elevation: elevation,
          shadowColor: AppStyle.black.withValues(alpha: 0.25),
          fixedSize: const Size.square(_size),
          shape: const CircleBorder(),
        ),
      ),
    );
  }
}
