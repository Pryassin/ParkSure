import 'package:flutter/material.dart';

import '../theme/app_style.dart';
import 'app_icon.dart';

enum AppButtonVariant {
  /// Black pill, white text. Main action: "Apply permit", "Got it".
  primary,

  /// White pill with a border. Alternative action.
  secondary,

  /// No background. Low-emphasis action: "Remove", "Back to now".
  text,
}

enum AppButtonSize {
  small(36),
  medium(AppStyle.buttonHeight);

  const AppButtonSize(this.height);
  final double height;
}

/// The one button used across the app.
///
/// Pass `onPressed: null` to disable it.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.medium,
    this.leadingIcon,
    this.trailingIcon,
    this.isExpanded = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? leadingIcon;
  final IconData? trailingIcon;

  /// Stretch to the full available width.
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    final colors = _ButtonColors.of(variant);

    final button = TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: colors.background,
        foregroundColor: colors.foreground,
        disabledBackgroundColor:
            variant == AppButtonVariant.text ? null : AppStyle.surface,
        disabledForegroundColor: AppStyle.textMuted,
        minimumSize: Size(0, size.height),
        padding: EdgeInsets.symmetric(
          horizontal:
              size == AppButtonSize.small ? AppStyle.spaceMd : AppStyle.spaceLg,
        ),
        shape: StadiumBorder(side: BorderSide(color: colors.border)),
        textStyle: AppStyle.button,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: AppStyle.spaceXs,
        children: [
          if (leadingIcon != null) AppIcon(leadingIcon!, size: AppIconSize.small),
          Text(label),
          if (trailingIcon != null) AppIcon(trailingIcon!, size: AppIconSize.small),
        ],
      ),
    );

    return isExpanded
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }
}

/// The colors for each variant, kept in one place.
class _ButtonColors {
  const _ButtonColors(this.background, this.foreground, this.border);

  final Color background;
  final Color foreground;
  final Color border;

  static _ButtonColors of(AppButtonVariant variant) => switch (variant) {
        AppButtonVariant.primary =>
          const _ButtonColors(AppStyle.black, AppStyle.white, Colors.transparent),
        AppButtonVariant.secondary =>
          const _ButtonColors(AppStyle.white, AppStyle.textPrimary, AppStyle.border),
        AppButtonVariant.text =>
          const _ButtonColors(Colors.transparent, AppStyle.textPrimary, Colors.transparent),
      };
}
