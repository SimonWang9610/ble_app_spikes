import 'dart:typed_data';

import 'package:ble_poc_dart/ble_poc_dart.dart';
import 'package:flutter_app/core/ble/characteristic_ref.dart';
import 'package:flutter_app/core/ble/stream_bridge.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ble_service.g.dart';

@Riverpod(keepAlive: true)
BleService _bleService(Ref ref) => BleService();

// Each model reads only the interface it uses.

@Riverpod(keepAlive: true)
BleAdapter bleAdapter(Ref ref) => ref.watch(_bleServiceProvider);

@Riverpod(keepAlive: true)
DeviceLink deviceLink(Ref ref) => ref.watch(_bleServiceProvider);

@Riverpod(keepAlive: true)
GattIO gattIO(Ref ref) => ref.watch(_bleServiceProvider);

/// The manager: initialize, adapter state, scanning.
abstract interface class BleAdapter {
  Future<void> initialize(Duration defaultTimeout);
  Stream<BluetoothAdapterState> adapterStates();
  Future<void> startScan(List<String> names);
  Future<void> stopScan();
  Stream<List<ScanResult>> scanResults();
}

/// The link to one device.
abstract interface class DeviceLink {
  Future<void> connect(String remoteId, Duration timeout);
  Future<void> disconnect(String remoteId);
  Stream<BluetoothConnectionState> connectionStates(String remoteId);
  Future<List<BluetoothService>> discoverServices(String remoteId);
  int mtu(String remoteId);
  Future<int> readRssi(String remoteId);

  /// Drops and disposes the cached handle, so the next session starts from a fresh one.
  void forget(String remoteId);
}

/// Reads, writes and notifications of one characteristic.
abstract interface class GattIO {
  Future<Uint8List> read(CharacteristicRef ref);
  Future<void> write(CharacteristicRef ref, List<int> value, {required bool withoutResponse});
  Future<bool> setNotify(CharacteristicRef ref, bool enable);
  Stream<Uint8List> values(CharacteristicRef ref);
}

/// The only code that touches the binding (loaded in `main`); holds no UI state.
class BleService implements BleAdapter, DeviceLink, GattIO {
  BleManager? _manager;
  // Handles share the core's state; keeping one per device until `forget` keeps the core from forgetting it.
  final _devices = <String, BluetoothDevice>{};

  BleManager get _requireManager => _manager ?? (throw StateError('initialize first'));

  @override
  Future<void> initialize(Duration defaultTimeout) async {
    final manager = _manager ??= BleManager();
    await manager.initialize(options: InitOptions(defaultTimeout: defaultTimeout));
  }

  @override
  Stream<BluetoothAdapterState> adapterStates() {
    final stream = _requireManager.adapterState();
    return bridge(stream.items(), stream.close);
  }

  @override
  Future<void> startScan(List<String> names) => _requireManager.startScan(
    options: ScanOptions(withServices: [], withNames: names),
  );

  @override
  Future<void> stopScan() => _requireManager.stopScan();

  @override
  Stream<List<ScanResult>> scanResults() {
    final stream = _requireManager.scanResults();
    return bridge(stream.items(), stream.close);
  }

  @override
  Future<void> connect(String remoteId, Duration timeout) => _device(remoteId).connect(timeout: timeout);

  @override
  Future<void> disconnect(String remoteId) => _device(remoteId).disconnect();

  @override
  Stream<BluetoothConnectionState> connectionStates(String remoteId) {
    final stream = _device(remoteId).connectionState();
    return bridge(stream.items(), stream.close);
  }

  @override
  Future<List<BluetoothService>> discoverServices(String remoteId) => _device(remoteId).discoverServices();

  @override
  int mtu(String remoteId) => _device(remoteId).mtuNow();

  @override
  Future<int> readRssi(String remoteId) => _device(remoteId).readRssi();

  @override
  void forget(String remoteId) => _devices.remove(remoteId)?.dispose();

  @override
  Future<Uint8List> read(CharacteristicRef ref) => _characteristic(ref).read();

  @override
  Future<void> write(CharacteristicRef ref, List<int> value, {required bool withoutResponse}) =>
      _characteristic(ref).write(value: value, withoutResponse: withoutResponse);

  @override
  Future<bool> setNotify(CharacteristicRef ref, bool enable) => _characteristic(ref).setNotifyValue(enable: enable);

  @override
  Stream<Uint8List> values(CharacteristicRef ref) {
    final stream = _characteristic(ref).onValueReceived();
    return bridge(stream.items(), stream.close);
  }

  BluetoothDevice _device(String remoteId) => _devices[remoteId] ??= _requireManager.device(remoteId: remoteId);

  BluetoothCharacteristic _characteristic(CharacteristicRef ref) =>
      _device(ref.remoteId).characteristic(serviceUuid: ref.service, characteristicUuid: ref.characteristic);
}
