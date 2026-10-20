import 'dart:async';

import 'package:ble_poc_dart/ble_poc_dart.dart';
import 'package:flutter_app/core/ble/ble_service.dart';
import 'package:flutter_app/core/fixture/fixture.dart';
import 'package:flutter_app/core/log/logger.dart';
import 'package:flutter_app/core/utils/errors.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'nearby.g.dart';

class NearbyState {
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
}

/// Nearby devices, for the Nearby screen only; one scan at a time, stopped when the screen goes away.
@riverpod
class Nearby extends _$Nearby {
  StreamSubscription<List<ScanResult>>? _results;
  late Logger _log;
  bool _active = false;
  // Bumped by every start / stop, so an older one stops after its await.
  int _run = 0;

  BleAdapter get _adapter => ref.read(bleAdapterProvider);

  @override
  NearbyState build() {
    _log = ref.watch(loggerProvider);
    final adapter = _adapter;
    ref.onDispose(() {
      _results?.cancel();
      if (_active) adapter.stopScan().catchError((_) {});
    });
    return const NearbyState();
  }

  /// Start (the screen is visible) or stop (it isn't) scanning.
  Future<void> setScanning(bool active) async {
    final run = ++_run;
    _active = active;
    await _results?.cancel();
    _results = null;
    if (!ref.mounted || run != _run) return;
    final adapter = _adapter;
    if (!active) {
      state = state.copyWith(scanning: false);
      await adapter.stopScan().catchError((_) {});
      return;
    }
    final names = state.onlyFixtures ? [Fixture.name] : <String>[];
    state = state.copyWith(results: const [], scanning: false);
    try {
      final results = adapter.scanResults();
      await _log.api('startScan(withNames: $names)', () => adapter.startScan(names));
      if (!ref.mounted || run != _run) return;
      state = state.copyWith(scanning: true);
      _results = results.listen(
        (list) => state = state.copyWith(results: [...list]..sort((a, b) => b.rssi.compareTo(a.rssi))),
        onError: _failed,
      );
    } catch (error) {
      if (ref.mounted && run == _run) _failed(error);
    }
  }

  void setOnlyFixtures(bool on) {
    state = state.copyWith(onlyFixtures: on);
    if (_active) setScanning(true);
  }

  void _failed(Object error) {
    state = state.copyWith(scanning: false, error: describeError(error));
    _log.error('Scan failed: ${describeError(error)}');
  }
}
