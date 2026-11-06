import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parksure_app/core/widgets/widgets.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  testWidgets('AppButton calls onPressed when tapped', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _wrap(AppButton(label: 'Apply permit', onPressed: () => taps++)),
    );

    await tester.tap(find.text('Apply permit'));
    expect(taps, 1);
  });

  testWidgets('AppButton with null onPressed is disabled', (tester) async {
    await tester.pumpWidget(
      _wrap(const AppButton(label: 'Apply permit', onPressed: null)),
    );

    final button = tester.widget<TextButton>(find.byType(TextButton));
    expect(button.enabled, isFalse);
  });

  testWidgets('AppIconButton shows its tooltip and handles taps',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _wrap(AppIconButton(
        icon: AppIcons.locate,
        tooltip: 'Center on my location',
        onPressed: () => taps++,
      )),
    );

    expect(find.byTooltip('Center on my location'), findsOneWidget);
    await tester.tap(find.byType(IconButton));
    expect(taps, 1);
  });

  testWidgets('AppDropdown opens, lists items and reports the choice',
      (tester) async {
    String? chosen;
    await tester.pumpWidget(
      _wrap(AppDropdown<String>(
        value: 'now',
        items: const [
          AppDropdownItem(value: 'now', label: 'Now'),
          AppDropdownItem(value: 'later', label: 'Later'),
        ],
        onChanged: (value) => chosen = value,
      )),
    );

    expect(find.text('Now'), findsOneWidget);

    await tester.tap(find.text('Now'));
    await tester.pumpAndSettle();
    expect(find.text('Later'), findsOneWidget);

    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    expect(chosen, 'later');
  });
}
