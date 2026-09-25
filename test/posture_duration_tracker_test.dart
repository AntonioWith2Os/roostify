import 'package:coolapp/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('folds a short abnormal streak back to normal', () {
    var now = DateTime(2026, 1, 1, 12);
    final tracker = PostureDurationTracker(
      sustainedAbnormalThreshold: const Duration(minutes: 5),
      clock: () => now,
    );

    expect(tracker.evaluate('cam', HealthState.abnormal), HealthState.normal);

    now = now.add(const Duration(minutes: 2));
    expect(tracker.evaluate('cam', HealthState.abnormal), HealthState.normal);
  });

  test('surfaces abnormal once the streak clears the threshold', () {
    var now = DateTime(2026, 1, 1, 12);
    final tracker = PostureDurationTracker(
      sustainedAbnormalThreshold: const Duration(minutes: 5),
      clock: () => now,
    );

    tracker.evaluate('cam', HealthState.abnormal);
    now = now.add(const Duration(minutes: 5));

    expect(tracker.evaluate('cam', HealthState.abnormal), HealthState.abnormal);
  });

  test('a normal reading resets the streak', () {
    var now = DateTime(2026, 1, 1, 12);
    final tracker = PostureDurationTracker(
      sustainedAbnormalThreshold: const Duration(minutes: 5),
      clock: () => now,
    );

    tracker.evaluate('cam', HealthState.abnormal);
    now = now.add(const Duration(minutes: 4));
    tracker.evaluate('cam', HealthState.normal);
    now = now.add(const Duration(minutes: 2));

    // Only 2 minutes into the new abnormal streak, well under the threshold.
    expect(tracker.evaluate('cam', HealthState.abnormal), HealthState.normal);
  });

  test('consumeSustainedAlert fires once per streak', () {
    var now = DateTime(2026, 1, 1, 12);
    final tracker = PostureDurationTracker(
      sustainedAbnormalThreshold: const Duration(minutes: 5),
      clock: () => now,
    );

    tracker.evaluate('cam', HealthState.abnormal);
    now = now.add(const Duration(minutes: 5));
    final effective = tracker.evaluate('cam', HealthState.abnormal);

    expect(tracker.consumeSustainedAlert('cam', effective), isTrue);
    expect(tracker.consumeSustainedAlert('cam', effective), isFalse);

    tracker.evaluate('cam', HealthState.normal);
    tracker.evaluate('cam', HealthState.abnormal);
    now = now.add(const Duration(minutes: 5));
    final nextEffective = tracker.evaluate('cam', HealthState.abnormal);

    expect(tracker.consumeSustainedAlert('cam', nextEffective), isTrue);
  });

  test('clear resets a key back to a fresh streak', () {
    var now = DateTime(2026, 1, 1, 12);
    final tracker = PostureDurationTracker(
      sustainedAbnormalThreshold: const Duration(minutes: 5),
      clock: () => now,
    );

    tracker.evaluate('cam', HealthState.abnormal);
    now = now.add(const Duration(minutes: 5));
    tracker.clear('cam');

    expect(tracker.evaluate('cam', HealthState.abnormal), HealthState.normal);
  });
}
