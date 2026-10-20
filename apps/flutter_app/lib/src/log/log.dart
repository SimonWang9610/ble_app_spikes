import 'dart:async';

import '../ble/ble_service.dart';

enum LogKind { event, value, error, api }

class LogEntry {
  LogEntry(this.kind, this.text) : time = DateTime.now();

  final DateTime time;
  final LogKind kind;
  final String text;
}

/// What happened to the device, in plain words ("Link lost", "NOTIFY received 42").
/// Anyone writes with `Log.event(...)` etc.; `logEntriesProvider` reads [entries] for the panel.
/// A broadcast stream without a buffer: lines before the panel listens are dropped.
class Log {
  Log._();

  static final shared = Log._();

  final _entries = StreamController<LogEntry>.broadcast();
  Stream<LogEntry> get entries => _entries.stream;

  static void event(String text) => shared._add(LogKind.event, text);
  static void value(String text) => shared._add(LogKind.value, text);
  static void error(String text) => shared._add(LogKind.error, text);

  /// Runs one binding call and logs it as an API line (shown only when "API calls" is on).
  static Future<T> api<T>(String call, Future<T> Function() body) async {
    shared._add(LogKind.api, call);
    try {
      final result = await body();
      shared._add(LogKind.api, '$call ok');
      return result;
    } catch (error) {
      shared._add(LogKind.api, '$call ✗ ${describeError(error)}');
      rethrow;
    }
  }

  void _add(LogKind kind, String text) => _entries.add(LogEntry(kind, text));
}
