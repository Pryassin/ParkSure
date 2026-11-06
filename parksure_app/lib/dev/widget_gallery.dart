import 'package:flutter/material.dart';

import '../core/widgets/widgets.dart';

/// Dev-only screen that shows every shared widget with its name,
/// so you can check the look in one place.
class WidgetGallery extends StatefulWidget {
  const WidgetGallery({super.key});

  @override
  State<WidgetGallery> createState() => _WidgetGalleryState();
}

class _WidgetGalleryState extends State<WidgetGallery> {
  String _time = 'now';
  String? _permit;

  void _noop() {}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyle.background,
      appBar: AppBar(
        title: const Text('Widget gallery', style: AppStyle.heading),
        backgroundColor: AppStyle.background,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppStyle.spaceMd),
        children: [
          _Section(
            title: 'AppButton',
            children: [
              _Labeled(
                name: 'primary',
                child: AppButton(label: 'Apply permit', onPressed: _noop),
              ),
              _Labeled(
                name: 'secondary',
                child: AppButton(
                  label: 'Cancel',
                  variant: AppButtonVariant.secondary,
                  onPressed: _noop,
                ),
              ),
              _Labeled(
                name: 'text',
                child: AppButton(
                  label: 'Remove',
                  variant: AppButtonVariant.text,
                  onPressed: _noop,
                ),
              ),
              _Labeled(
                name: 'primary · small',
                child: AppButton(
                  label: 'Today',
                  size: AppButtonSize.small,
                  onPressed: _noop,
                ),
              ),
              _Labeled(
                name: 'secondary · small',
                child: AppButton(
                  label: 'Tomorrow',
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.small,
                  onPressed: _noop,
                ),
              ),
              _Labeled(
                name: 'leadingIcon',
                child: AppButton(
                  label: 'Back to now',
                  leadingIcon: AppIcons.time,
                  variant: AppButtonVariant.secondary,
                  onPressed: _noop,
                ),
              ),
              _Labeled(
                name: 'trailingIcon',
                child: AppButton(
                  label: 'Signs on this curb',
                  trailingIcon: AppIcons.chevronDown,
                  variant: AppButtonVariant.text,
                  onPressed: _noop,
                ),
              ),
              const _Labeled(
                name: 'disabled (onPressed: null)',
                child: AppButton(label: 'Apply permit', onPressed: null),
              ),
            ],
          ),
          _Labeled(
            name: 'AppButton · isExpanded',
            child: AppButton(
              label: 'Got it',
              isExpanded: true,
              onPressed: _noop,
            ),
          ),
          const SizedBox(height: AppStyle.spaceLg),
          _Section(
            title: 'AppIconButton',
            children: [
              _Labeled(
                name: 'floating',
                child: AppIconButton(
                  icon: AppIcons.locate,
                  tooltip: 'My location',
                  onPressed: _noop,
                ),
              ),
              _Labeled(
                name: 'filled',
                child: AppIconButton(
                  icon: AppIcons.info,
                  tooltip: 'Info',
                  variant: AppIconButtonVariant.filled,
                  onPressed: _noop,
                ),
              ),
              _Labeled(
                name: 'plain',
                child: AppIconButton(
                  icon: AppIcons.close,
                  tooltip: 'Close',
                  variant: AppIconButtonVariant.plain,
                  onPressed: _noop,
                ),
              ),
              const _Labeled(
                name: 'disabled',
                child: AppIconButton(
                  icon: AppIcons.zoomIn,
                  tooltip: 'Zoom in',
                  onPressed: null,
                ),
              ),
            ],
          ),
          _Section(
            title: 'AppDropdown',
            children: [
              _Labeled(
                name: 'with value',
                child: AppDropdown<String>(
                  value: _time,
                  items: const [
                    AppDropdownItem(value: 'now', label: 'Now'),
                    AppDropdownItem(value: 'pick', label: 'Pick a time'),
                  ],
                  onChanged: (v) => setState(() => _time = v),
                ),
              ),
              _Labeled(
                name: 'placeholder + icons',
                child: AppDropdown<String>(
                  value: _permit,
                  placeholder: 'Permit',
                  items: const [
                    AppDropdownItem(
                      value: 'srr-198',
                      label: 'SRR 198',
                      icon: AppIcons.permit,
                    ),
                    AppDropdownItem(
                      value: 'none',
                      label: 'No permit',
                      icon: AppIcons.close,
                    ),
                  ],
                  onChanged: (v) => setState(() => _permit = v),
                ),
              ),
            ],
          ),
          const _Section(
            title: 'AppTooltip (hover or long-press)',
            children: [
              _Labeled(
                name: 'AppTooltip',
                child: AppTooltip(
                  message: 'Always check the posted signs',
                  child: AppIcon(AppIcons.info),
                ),
              ),
            ],
          ),
          _Section(
            title: 'AppIcons',
            children: [
              for (final (name, icon) in _icons)
                _Labeled(name: name, child: AppIcon(icon)),
            ],
          ),
        ],
      ),
    );
  }
}

const _icons = [
  ('locate', AppIcons.locate),
  ('chevronDown', AppIcons.chevronDown),
  ('chevronUp', AppIcons.chevronUp),
  ('check', AppIcons.check),
  ('close', AppIcons.close),
  ('info', AppIcons.info),
  ('time', AppIcons.time),
  ('permit', AppIcons.permit),
  ('offline', AppIcons.offline),
  ('zoomIn', AppIcons.zoomIn),
];

/// A titled group of widgets laid out side by side, wrapping to new lines.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppStyle.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppStyle.spaceSm,
        children: [
          Text(title, style: AppStyle.heading),
          Wrap(
            spacing: AppStyle.spaceMd,
            runSpacing: AppStyle.spaceMd,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: children,
          ),
        ],
      ),
    );
  }
}

/// A widget with its variant name written underneath.
class _Labeled extends StatelessWidget {
  const _Labeled({required this.name, required this.child});

  final String name;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: AppStyle.spaceXs,
      children: [child, Text(name, style: AppStyle.small)],
    );
  }
}
