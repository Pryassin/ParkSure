import 'package:flutter_test/flutter_test.dart';
import 'package:parksure_app/core/domain/curb_status.dart';
import 'package:parksure_app/features/verdict/domain/curb_answer.dart';

Verdict _verdict({DateTime? validUntil}) => Verdict(
      status: CurbStatus.conditions,
      reason: 'No parking starts at 10:00',
      disclaimer: 'Always check the posted signs.',
      validUntil: validUntil,
    );

void main() {
  final now = DateTime(2026, 11, 6, 9, 35);

  group('timeLeft', () {
    test('is the time until validUntil', () {
      final verdict = _verdict(validUntil: DateTime(2026, 11, 6, 10, 0));
      expect(verdict.timeLeft(now), const Duration(minutes: 25));
    });

    test('is null when there is no end time', () {
      expect(_verdict().timeLeft(now), isNull);
    });

    test('is zero when validUntil has passed', () {
      final verdict = _verdict(validUntil: DateTime(2026, 11, 6, 9, 0));
      expect(verdict.timeLeft(now), Duration.zero);
    });
  });

  test('a switch over CurbAnswer handles every case', () {
    String describe(CurbAnswer answer) => switch (answer) {
          Verdict() => 'verdict',
          PickSide() => 'pick side',
        };

    expect(describe(_verdict()), 'verdict');
    expect(describe(const PickSide([])), 'pick side');
  });
}
