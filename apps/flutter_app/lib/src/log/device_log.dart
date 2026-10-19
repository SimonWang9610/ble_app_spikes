import 'dart:async';

import '../ble/ble_service.dart';

enum LogKind { event, value, error, api }

class LogEntry {
  LogEntry(this.kind, this.text) : time = DateTime.now();

  final DateTime time;
  final LogKind kind;
  final String text;
}

/// Where blocs report what happened, in plain words ("Link lost", "NOTIFY received 42").
/// A repository, not a bloc: blocs write to it and `LogCubit` reads from it, so no bloc depends on another.
class DeviceLog {
  final _entries = StreamController<LogEntry>.broadcast();

  Stream<LogEntry> get entries => _entries.stream;

  void event(String text) => _entries.add(LogEntry(LogKind.event, text));
  void value(String text) => _entries.add(LogEntry(LogKind.value, text));
  void error(String text) => _entries.add(LogEntry(LogKind.error, text));

  /// Runs one binding call and logs it as an API line (shown only when "API calls" is on).
  Future<T> api<T>(String call, Future<T> Function() body) async {
    _entries.add(LogEntry(LogKind.api, call));
    try {
      final result = await body();
      _entries.add(LogEntry(LogKind.api, '$call ok'));
      return result;
    } catch (error) {
      _entries.add(LogEntry(LogKind.api, '$call ✗ ${describeError(error)}'));
      rethrow;
    }
  }
}
