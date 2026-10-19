import 'dart:async';
import 'dart:typed_data';

import 'package:ble_poc_dart/ble_poc_dart.dart';

/// Identifies one characteristic of one device.
class CharacteristicRef {
  const CharacteristicRef(this.remoteId, this.service, this.characteristic);

  final String remoteId;
  final String service;
  final String characteristic;
}

/// The only code that touches the binding. Controllers call it; it holds no UI state.
class BleService {
  Future<void>? _binding;
  BleManager? _manager;
  // Handles share the core's state; keeping one per device until `forget` keeps the core from forgetting it.
  final _devices = <String, BluetoothDevice>{};

  BleManager get _requireManager => _manager ?? (throw StateError('initialize first'));

  // Adapter

  Future<void> initialize(Duration defaultTimeout) async {
    // The native lib must load once before any other binding call.
    await (_binding ??= initDartBinding());
    final manager = _manager ??= BleManager();
    await manager.initialize(options: InitOptions(defaultTimeout: defaultTimeout));
  }

  Stream<BluetoothAdapterState> adapterStates() {
    final stream = _requireManager.adapterState();
    return _bridge(stream.items(), stream.close);
  }

  // Scan

  Future<void> startScan(List<String> names) => _requireManager.startScan(
    options: ScanOptions(withServices: [], withNames: names),
  );

  Future<void> stopScan() => _requireManager.stopScan();

  Stream<List<ScanResult>> scanResults() {
    final stream = _requireManager.scanResults();
    return _bridge(stream.items(), stream.close);
  }

  // Device

  Future<void> connect(String remoteId, Duration timeout) => _device(remoteId).connect(timeout: timeout);

  Future<void> disconnect(String remoteId) => _device(remoteId).disconnect();

  Stream<BluetoothConnectionState> connectionStates(String remoteId) {
    final stream = _device(remoteId).connectionState();
    return _bridge(stream.items(), stream.close);
  }

  Future<List<BluetoothService>> discoverServices(String remoteId) => _device(remoteId).discoverServices();

  List<BluetoothService> servicesList(String remoteId) => _device(remoteId).servicesList();

  int mtu(String remoteId) => _device(remoteId).mtuNow();

  Future<int> readRssi(String remoteId) => _device(remoteId).readRssi();

  /// Drops and disposes the cached handle, so the next session starts from a fresh one.
  void forget(String remoteId) => _devices.remove(remoteId)?.dispose();

  // Characteristic

  Future<Uint8List> read(CharacteristicRef ref) => _characteristic(ref).read();

  Future<void> write(CharacteristicRef ref, List<int> value, {required bool withoutResponse}) =>
      _characteristic(ref).write(value: value, withoutResponse: withoutResponse);

  Future<bool> setNotify(CharacteristicRef ref, bool enable) => _characteristic(ref).setNotifyValue(enable: enable);

  bool isNotifying(CharacteristicRef ref) => _characteristic(ref).isNotifying();

  Stream<Uint8List> values(CharacteristicRef ref) {
    final stream = _characteristic(ref).onValueReceived();
    return _bridge(stream.items(), stream.close);
  }

  // Handles

  BluetoothDevice _device(String remoteId) => _devices[remoteId] ??= _requireManager.device(remoteId: remoteId);

  BluetoothCharacteristic _characteristic(CharacteristicRef ref) =>
      _device(ref.remoteId).characteristic(serviceUuid: ref.service, characteristicUuid: ref.characteristic);
}

/// Re-wraps a binding stream so its object is closed when the listener cancels.
Stream<T> _bridge<T>(Stream<T> items, void Function() close) {
  StreamSubscription<T>? subscription;
  late final StreamController<T> controller;
  controller = StreamController<T>(
    onListen: () => subscription = items.listen(controller.add, onError: controller.addError, onDone: controller.close),
    onCancel: () async {
      await subscription?.cancel();
      close();
    },
  );
  return controller.stream;
}

/// Binding errors already print as `BleError.platform(message: ...)`.
String describeError(Object error) => '$error';

/// For state reads that are only a nice-to-have (e.g. restoring the MTU when a screen opens).
T? tryOrNull<T>(T Function() body) {
  try {
    return body();
  } catch (_) {
    return null;
  }
}
