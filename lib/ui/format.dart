import 'package:intl/intl.dart';

/// Human-friendly relative time for chat rows and message stamps.
String relativeTime(int epochMs, {DateTime? now}) {
  final DateTime t = DateTime.fromMillisecondsSinceEpoch(epochMs);
  final DateTime currentNow = now ?? DateTime.now();
  final Duration delta = currentNow.difference(t);

  final yesterday =
      DateTime(currentNow.year, currentNow.month, currentNow.day - 1);

  if (delta.inSeconds < 45) return 'now';
  if (delta.inMinutes < 60) return '${delta.inMinutes}m';
  if (_isSameDay(t, currentNow)) return DateFormat.jm().format(t);
  if (_isSameDay(t, yesterday)) return 'Yesterday';
  if (delta.inDays < 7) return DateFormat.E().format(t); // Mon, Tue
  return DateFormat.MMMd().format(t); // Jul 25
}

/// Clock time shown inside a message bubble.
String clockTime(int epochMs) =>
    DateFormat.jm().format(DateTime.fromMillisecondsSinceEpoch(epochMs));

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
