import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:kabootar/ui/format.dart';

void main() {
  test('returns now for 10 seconds ago', () {
    final now = DateTime(2026, 12, 10, 10, 20);

    final messageTime = now.subtract(
      const Duration(seconds: 10),
    );

    final time = relativeTime(
      messageTime.millisecondsSinceEpoch,
      now: now,
    );

    expect(time, 'now');
  });

  test('returns 20m for 20 minutes ago', () {
    final now = DateTime(2026, 12, 10, 20);
    final messageTime = now.subtract(const Duration(minutes: 20));

    final time = relativeTime(messageTime.millisecondsSinceEpoch, now: now);

    expect(time, '20m');
  });

  test('returns the hour if sent earlier today', () {
    final now = DateTime(2026, 12, 10, 20);
    final messageTime = now.subtract(const Duration(hours: 12));

    final time = relativeTime(messageTime.millisecondsSinceEpoch, now: now);

    expect(time, DateFormat.jm().format(messageTime));
  });

  test('returns Yesterday for a day ago(with difference of more than 24 hours)',
      () {
    final now = DateTime(2026, 12, 10, 20);
    final messageTime = DateTime(2026, 12, 9, 10);

    final time = relativeTime(messageTime.millisecondsSinceEpoch, now: now);

    expect(time, 'Yesterday');
  });

  test('returns weekday for 3 days ago', () {
    final now = DateTime(2026, 12, 10, 20);
    final messageTime = DateTime(2026, 12, 7, 12);

    final time = relativeTime(messageTime.millisecondsSinceEpoch, now: now);

    expect(time, DateFormat.E().format(messageTime));
  });

  test('returns month and day for 3 months ago', () {
    final now = DateTime(2026, 12, 10);
    final messageTime = DateTime(2026, 9, 10);

    final time = relativeTime(messageTime.millisecondsSinceEpoch, now: now);

    expect(time, DateFormat.MMMd().format(messageTime));
  });
}
