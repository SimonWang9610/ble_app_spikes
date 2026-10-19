import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'device_log.dart';

class LogState extends Equatable {
  const LogState({this.entries = const [], this.showApiCalls = false});

  final List<LogEntry> entries;
  final bool showApiCalls;

  List<LogEntry> get visible => showApiCalls ? entries : entries.where((e) => e.kind != LogKind.api).toList();

  LogState copyWith({List<LogEntry>? entries, bool? showApiCalls}) =>
      LogState(entries: entries ?? this.entries, showApiCalls: showApiCalls ?? this.showApiCalls);

  @override
  List<Object?> get props => [entries, showApiCalls];
}

/// The log panel's state. A Cubit: it only collects entries and toggles a filter.
class LogCubit extends Cubit<LogState> {
  LogCubit(DeviceLog log) : super(const LogState()) {
    _subscription = log.entries.listen(_add);
  }

  static const _limit = 500;
  late final StreamSubscription<LogEntry> _subscription;

  void _add(LogEntry entry) {
    final entries = [...state.entries, entry];
    emit(state.copyWith(entries: entries.length > _limit ? entries.sublist(entries.length - _limit) : entries));
  }

  void clear() => emit(state.copyWith(entries: const []));

  void setShowApiCalls(bool on) => emit(state.copyWith(showApiCalls: on));

  @override
  Future<void> close() {
    _subscription.cancel();
    return super.close();
  }
}
