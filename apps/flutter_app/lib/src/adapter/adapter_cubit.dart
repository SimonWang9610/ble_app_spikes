import 'dart:async';

import 'package:ble_poc_dart/ble_poc_dart.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../ble/ble_service.dart';
import '../log/device_log.dart';

class AdapterState extends Equatable {
  const AdapterState({this.initialized = false, this.bluetooth, this.error});

  final bool initialized;
  final BluetoothAdapterState? bluetooth;
  final String? error;

  @override
  List<Object?> get props => [initialized, bluetooth, error];
}

/// Initializes the manager once and mirrors the adapter state. A Cubit: one call and one stream.
class AdapterCubit extends Cubit<AdapterState> {
  AdapterCubit(this._service, this._log) : super(const AdapterState());

  final BleService _service;
  final DeviceLog _log;
  StreamSubscription<BluetoothAdapterState>? _subscription;

  Future<void> start() async {
    try {
      await _log.api('initialize(defaultTimeout: 15s)', () => _service.initialize(const Duration(seconds: 15)));
      emit(const AdapterState(initialized: true));
      _subscription = _service.adapterStates().listen((bluetooth) {
        emit(AdapterState(initialized: true, bluetooth: bluetooth));
        _log.event(bluetooth == BluetoothAdapterState.poweredOn ? 'Bluetooth on' : 'Bluetooth ${bluetooth.name}');
      }, onError: _failed);
    } catch (error) {
      _failed(error);
    }
  }

  void _failed(Object error) {
    emit(AdapterState(initialized: state.initialized, bluetooth: state.bluetooth, error: describeError(error)));
    _log.error('Bluetooth unavailable: ${describeError(error)}');
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
