import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/app_style.dart';
import 'app_button.dart';
import 'app_icon.dart';

/// One choice in an [AppDropdown].
class AppDropdownItem<T> {
  const AppDropdownItem({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// A pill-shaped dropdown, like "Now ▾" and "Permit ▾" in the top bar.
///
/// The trigger is a small text [AppButton] with a chevron. The selected item
/// gets a check mark.
class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    super.key,
    required this.items,
    required this.onChanged,
    this.value,
    this.placeholder = '',
  });

  final List<AppDropdownItem<T>> items;
  final ValueChanged<T> onChanged;

  /// The selected value, or null to show [placeholder].
  final T? value;
  final String placeholder;

  String get _selectedLabel {
    for (final item in items) {
      if (item.value == value) return item.label;
    }
    return placeholder;
  }

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(AppStyle.white),
        elevation: const WidgetStatePropertyAll(4),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppStyle.radiusMd),
            side: const BorderSide(color: AppStyle.border),
          ),
        ),
      ),
      menuChildren: [
        for (final item in items)
          MenuItemButton(
            onPressed: () => onChanged(item.value),
            leadingIcon: item.icon == null
                ? null
                : AppIcon(item.icon!, size: AppIconSize.small),
            trailingIcon: item.value == value
                ? const AppIcon(AppIcons.check, size: AppIconSize.small)
                : null,
            child: Text(item.label, style: AppStyle.body),
          ),
      ],
      builder: (context, controller, _) => AppButton(
        label: _selectedLabel,
        variant: AppButtonVariant.text,
        size: AppButtonSize.small,
        trailingIcon:
            controller.isOpen ? AppIcons.chevronUp : AppIcons.chevronDown,
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}
