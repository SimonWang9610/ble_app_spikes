import 'dart:async';

import 'package:ble_poc_dart/ble_poc_dart.dart';
import 'package:flutter_app/core/ble/ble_service.dart';
import 'package:flutter_app/core/log/logger.dart';
import 'package:flutter_app/core/utils/errors.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'adapter.g.dart';

class AdapterView {
  const AdapterView({this.initialized = false, this.bluetooth, this.error});

  final bool initialized;
  final BluetoothAdapterState? bluetooth;
  final String? error;
}

/// Initializes the manager once and mirrors the adapter state.
@Riverpod(keepAlive: true)
class Adapter extends _$Adapter {
  late Logger _log;
  StreamSubscription<BluetoothAdapterState>? _subscription;

  @override
  AdapterView build() {
    _log = ref.watch(loggerProvider);
    ref.onDispose(() => _subscription?.cancel());
    unawaited(_start());
    return const AdapterView();
  }

  Future<void> _start() async {
    final adapter = ref.read(bleAdapterProvider);
    try {
      await _log.api('initialize(defaultTimeout: 15s)', () => adapter.initialize(const Duration(seconds: 15)));
      state = const AdapterView(initialized: true);
      _subscription = adapter.adapterStates().listen((bluetooth) {
        state = AdapterView(initialized: true, bluetooth: bluetooth);
        _log.event(bluetooth == BluetoothAdapterState.poweredOn ? 'Bluetooth on' : 'Bluetooth ${bluetooth.name}');
      }, onError: _failed);
    } catch (error) {
      _failed(error);
    }
  }

  void _failed(Object error) {
    state = AdapterView(initialized: state.initialized, bluetooth: state.bluetooth, error: describeError(error));
    _log.error('Bluetooth unavailable: ${describeError(error)}');
  }
}
