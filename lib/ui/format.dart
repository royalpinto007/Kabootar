import 'package:intl/intl.dart';

/// Human-friendly relative time for chat rows and message stamps.
String relativeTime(int epochMs, {DateTime? now}) {
  final DateTime t = DateTime.fromMillisecondsSinceEpoch(epochMs);
  final DateTime reference = now ?? DateTime.now();
  final Duration delta = reference.difference(t);

  if (delta.inSeconds < 45) return 'now';
  if (delta.inMinutes < 60) return '${delta.inMinutes}m';
  final DateTime today = DateTime(reference.year, reference.month, reference.day);
  final DateTime day = DateTime(t.year, t.month, t.day);
  final int calendarDays = today.difference(day).inDays;
  if (calendarDays <= 0) return DateFormat.jm().format(t);
  if (calendarDays == 1) return 'Yesterday';
  if (calendarDays < 7) return DateFormat.E().format(t); // Mon, Tue
  return DateFormat.MMMd().format(t); // Jul 25
}

/// Clock time shown inside a message bubble.
String clockTime(int epochMs) =>
    DateFormat.jm().format(DateTime.fromMillisecondsSinceEpoch(epochMs));
