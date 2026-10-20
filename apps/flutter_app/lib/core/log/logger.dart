import 'dart:async';

import 'package:flutter_app/core/utils/errors.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'logger.g.dart';

enum LogKind { event, value, error, api }

class LogEntry {
  LogEntry(this.kind, this.text) : time = DateTime.now();

  final DateTime time;
  final LogKind kind;
  final String text;
}

/// What happened to the device, in plain words ("Link lost", "NOTIFY received 42").
/// A broadcast stream without a buffer: lines before the log panel listens are dropped.
class Logger {
  final _entries = StreamController<LogEntry>.broadcast();

  Stream<LogEntry> get entries => _entries.stream;

  void event(String text) => _add(LogKind.event, text);
  void value(String text) => _add(LogKind.value, text);
  void error(String text) => _add(LogKind.error, text);

  /// Runs one binding call and logs it as an API line (shown only when "API calls" is on).
  Future<T> api<T>(String call, Future<T> Function() body) async {
    _add(LogKind.api, call);
    try {
      final result = await body();
      _add(LogKind.api, '$call ok');
      return result;
    } catch (error) {
      _add(LogKind.api, '$call ✗ ${describeError(error)}');
      rethrow;
    }
  }

  Future<void> close() => _entries.close();

  void _add(LogKind kind, String text) {
    if (!_entries.isClosed) _entries.add(LogEntry(kind, text));
  }
}

@Riverpod(keepAlive: true)
Logger logger(Ref ref) {
  final logger = Logger();
  ref.onDispose(logger.close);
  return logger;
}
