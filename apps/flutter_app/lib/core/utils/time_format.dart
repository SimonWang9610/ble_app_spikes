/// "14:03:27", local time.
String formatTime(DateTime time) => time.toIso8601String().substring(11, 19);
