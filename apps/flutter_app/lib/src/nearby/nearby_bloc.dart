import 'package:ble_poc_dart/ble_poc_dart.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../ble/ble_service.dart';
import '../fixture.dart';
import '../log/device_log.dart';

sealed class NearbyEvent {
  const NearbyEvent();
}

/// Start (the screen is visible) or stop (it isn't) scanning.
class NearbyScanSet extends NearbyEvent {
  const NearbyScanSet(this.active);

  final bool active;
}

class NearbyFilterChanged extends NearbyEvent {
  const NearbyFilterChanged(this.onlyFixtures);

  final bool onlyFixtures;
}

class NearbyState extends Equatable {
  const NearbyState({this.onlyFixtures = true, this.scanning = false, this.results = const [], this.error});

  final bool onlyFixtures;
  final bool scanning;
  final List<ScanResult> results;
  final String? error;

  NearbyState copyWith({bool? onlyFixtures, bool? scanning, List<ScanResult>? results, String? error}) => NearbyState(
    onlyFixtures: onlyFixtures ?? this.onlyFixtures,
    scanning: scanning ?? this.scanning,
    results: results ?? this.results,
    error: error,
  );

  @override
  List<Object?> get props => [onlyFixtures, scanning, results, error];
}

/// Nearby devices. A Bloc: start / stop / filter events drive one scan at a time.
class NearbyBloc extends Bloc<NearbyEvent, NearbyState> {
  NearbyBloc(this._service, this._log) : super(const NearbyState()) {
    // `restartable`: a new start or stop cancels the running scan handler, so scans never overlap.
    on<NearbyScanSet>(_onScanSet, transformer: restartable());
    on<NearbyFilterChanged>(_onFilterChanged);
  }

  final BleService _service;
  final DeviceLog _log;
  bool _active = false;

  Future<void> _onScanSet(NearbyScanSet event, Emitter<NearbyState> emit) async {
    _active = event.active;
    if (!event.active) {
      emit(state.copyWith(scanning: false));
      await _service.stopScan().catchError((_) {});
      return;
    }
    final names = state.onlyFixtures ? [Fixture.name] : <String>[];
    emit(state.copyWith(results: const [], scanning: false));
    try {
      final results = _service.scanResults();
      await _log.api('startScan(withNames: $names)', () => _service.startScan(names));
      emit(state.copyWith(scanning: true));
      // Runs until the next NearbyScanSet replaces this handler.
      await emit.forEach(
        results,
        onData: (List<ScanResult> list) => state.copyWith(results: [...list]..sort((a, b) => b.rssi.compareTo(a.rssi))),
      );
    } catch (error) {
      emit(state.copyWith(scanning: false, error: describeError(error)));
      _log.error('Scan failed: ${describeError(error)}');
    }
  }

  void _onFilterChanged(NearbyFilterChanged event, Emitter<NearbyState> emit) {
    emit(state.copyWith(onlyFixtures: event.onlyFixtures));
    if (_active) add(const NearbyScanSet(true));
  }
}
