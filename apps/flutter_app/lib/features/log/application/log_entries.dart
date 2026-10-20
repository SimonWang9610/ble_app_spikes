import 'package:flutter_app/core/log/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'log_entries.g.dart';

class LogState {
  const LogState({this.entries = const [], this.showApiCalls = false});

  final List<LogEntry> entries;
  final bool showApiCalls;

  List<LogEntry> get visible => showApiCalls ? entries : entries.where((e) => e.kind != LogKind.api).toList();

  LogState copyWith({List<LogEntry>? entries, bool? showApiCalls}) =>
      LogState(entries: entries ?? this.entries, showApiCalls: showApiCalls ?? this.showApiCalls);
}

/// The log panel's state: the latest entries of the [Logger] and the API-calls filter.
@Riverpod(keepAlive: true)
class LogEntries extends _$LogEntries {
  static const _limit = 500;

  @override
  LogState build() {
    final subscription = ref.watch(loggerProvider).entries.listen(_add);
    ref.onDispose(subscription.cancel);
    return const LogState();
  }

  void _add(LogEntry entry) {
    final entries = [...state.entries, entry];
    state = state.copyWith(entries: entries.length > _limit ? entries.sublist(entries.length - _limit) : entries);
  }

  void clear() => state = state.copyWith(entries: const []);

  void setShowApiCalls(bool on) => state = state.copyWith(showApiCalls: on);
}
