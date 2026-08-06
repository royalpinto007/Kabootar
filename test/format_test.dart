import 'package:flutter_test/flutter_test.dart';
import 'package:kabootar/ui/format.dart';

void main() {
  final now = DateTime(2026, 8, 6, 18, 0);

  test('shows a clock time for a message sent earlier today', () {
    final t = DateTime(2026, 8, 6, 9, 0);

    expect(relativeTime(t.millisecondsSinceEpoch, now: now), isNot('Yesterday'));
  });

  test('shows Yesterday for a message sent yesterday morning and viewed today evening', () {
    final t = DateTime(2026, 8, 5, 9, 0);

    expect(relativeTime(t.millisecondsSinceEpoch, now: now), 'Yesterday');
  });

  test('shows a weekday for a message from three calendar days ago', () {
    final t = DateTime(2026, 8, 3, 9, 0);

    expect(relativeTime(t.millisecondsSinceEpoch, now: now), isNot('Yesterday'));
  });
}
