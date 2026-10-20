import 'dart:async';
import 'dart:typed_data';

import 'package:ble_poc_dart/ble_poc_dart.dart';
import 'package:flutter_app/core/ble/ble_service.dart';
import 'package:flutter_app/core/fixture/fixture.dart';
import 'package:flutter_riverpod/misc.dart';

const valueUuid = 'f0e10001-5a3e-4c1a-9d2b-1b2c3d4e5f60';
const notifyUuid = 'f0e10101-5a3e-4c1a-9d2b-1b2c3d4e5f60';
const dataService = 'f0e10000-5a3e-4c1a-9d2b-1b2c3d4e5f60';
const streamService = 'f0e10100-5a3e-4c1a-9d2b-1b2c3d4e5f60';
const deviceId = 'fixture-1';

CharacteristicProperties props({bool read = false, bool write = false, bool notify = false}) =>
    CharacteristicProperties(read: read, write: write, writeWithoutResponse: false, notify: notify, indicate: false);

/// The fixture's DATA and STREAM services, plus one service of the Mac's own.
List<BluetoothService> fixtureServices(String remoteId) => [
  BluetoothService(
    remoteId: remoteId,
    serviceUuid: dataService,
    isPrimary: true,
    characteristics: [CharacteristicInfo(characteristicUuid: valueUuid, properties: props(read: true, write: true))],
  ),
  BluetoothService(
    remoteId: remoteId,
    serviceUuid: streamService,
    isPrimary: true,
    characteristics: [CharacteristicInfo(characteristicUuid: notifyUuid, properties: props(notify: true))],
  ),
  BluetoothService(remoteId: remoteId, serviceUuid: '180a', isPrimary: true, characteristics: const []),
];

ScanResult scanResult(String id, int rssi, {String name = Fixture.name}) => ScanResult(
  remoteId: id,
  rssi: rssi,
  advertisementData: AdvertisementData(
    advName: name,
    manufacturerData: const {},
    serviceData: const {},
    serviceUuids: const [],
  ),
  timeStamp: DateTime(2026),
);

/// A scripted peripheral: records every call, links come up on connect and drop on [dropLink].
class FakeBle implements BleAdapter, DeviceLink, GattIO {
  final calls = <String>[];
  final adapter = StreamController<BluetoothAdapterState>.broadcast();
  final scan = StreamController<List<ScanResult>>.broadcast();
  final _links = <String, StreamController<BluetoothConnectionState>>{};
  final _values = <String, StreamController<Uint8List>>{};
  final _connected = <String>{};

  Object? initError;

  /// Connect attempts that fail before one succeeds.
  int connectFailures = 0;
  Uint8List readValue = Uint8List.fromList([0x68, 0x69]);
  final notifying = <String>{};

  List<Override> get overrides => [
    bleAdapterProvider.overrideWithValue(this),
    deviceLinkProvider.overrideWithValue(this),
    gattIOProvider.overrideWithValue(this),
  ];

  bool isConnected(String remoteId) => _connected.contains(remoteId);

  void dropLink(String remoteId) {
    _connected.remove(remoteId);
    _links[remoteId]?.add(BluetoothConnectionState.disconnected);
  }

  void push(String characteristic, List<int> value) => _values[characteristic]?.add(Uint8List.fromList(value));

  @override
  Future<void> initialize(Duration defaultTimeout) async {
    calls.add('initialize');
    if (initError case final error?) throw error;
  }

  @override
  Stream<BluetoothAdapterState> adapterStates() => adapter.stream;

  @override
  Future<void> startScan(List<String> names) async => calls.add('startScan $names');

  @override
  Future<void> stopScan() async => calls.add('stopScan');

  @override
  Stream<List<ScanResult>> scanResults() => scan.stream;

  @override
  Future<void> connect(String remoteId, Duration timeout) async {
    calls.add('connect $remoteId');
    if (connectFailures > 0) {
      connectFailures--;
      throw StateError('connect failed');
    }
    _connected.add(remoteId);
    _links[remoteId]?.add(BluetoothConnectionState.connected);
  }

  @override
  Future<void> disconnect(String remoteId) async {
    calls.add('disconnect $remoteId');
    _connected.remove(remoteId);
  }

  @override
  Stream<BluetoothConnectionState> connectionStates(String remoteId) {
    final link = _links[remoteId] ??= StreamController.broadcast();
    // Like the binding: the current state first.
    scheduleMicrotask(
      () =>
          link.add(isConnected(remoteId) ? BluetoothConnectionState.connected : BluetoothConnectionState.disconnected),
    );
    return link.stream;
  }

  @override
  Future<List<BluetoothService>> discoverServices(String remoteId) async {
    calls.add('discoverServices');
    return fixtureServices(remoteId);
  }

  @override
  int mtu(String remoteId) => 185;

  @override
  Future<int> readRssi(String remoteId) async => -42;

  @override
  void forget(String remoteId) => calls.add('forget $remoteId');

  @override
  Future<Uint8List> read(CharacteristicRef ref) async {
    calls.add('read ${Fixture.shortName(ref.characteristic)}');
    return readValue;
  }

  @override
  Future<void> write(CharacteristicRef ref, List<int> value, {required bool withoutResponse}) async =>
      calls.add('write ${Fixture.shortName(ref.characteristic)} $value');

  @override
  Future<bool> setNotify(CharacteristicRef ref, bool enable) async {
    calls.add('setNotify ${Fixture.shortName(ref.characteristic)} $enable');
    enable ? notifying.add(ref.characteristic) : notifying.remove(ref.characteristic);
    return true;
  }

  @override
  Stream<Uint8List> values(CharacteristicRef ref) =>
      (_values[ref.characteristic] ??= StreamController.broadcast()).stream;
}
