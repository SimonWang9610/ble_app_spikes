import 'package:ble_poc_dart/ble_poc_dart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../ble/ble_service.dart';
import '../fixture.dart';
import '../log/log.dart';
import 'characteristic.dart';
import 'current_device.dart';

part 'gatt.g.dart';

/// One service tile: its UUID and its characteristics in discovery order.
class ServiceGroup {
  const ServiceGroup(this.uuid, this.chars);

  final String uuid;
  final List<CharKey> chars;
}

/// What the current device offers, as service tiles. The characteristics' own state lives in
/// `characteristicProvider`, keyed so that it survives rediscovery.
@Riverpod(keepAlive: true)
class Gatt extends _$Gatt {
  @override
  List<ServiceGroup> build() {
    ref.watch(currentDeviceProvider);
    return const [];
  }

  Future<List<BluetoothService>> discover(String remoteId) {
    final link = ref.read(deviceLinkProvider);
    return Log.api('discoverServices()', () => link.discoverServices(remoteId));
  }

  /// Shows the fixture's services; throws if one of `subscribed` is missing from them.
  void apply(String remoteId, List<BluetoothService> all, {required Iterable<CharKey> subscribed}) {
    final found = Fixture.servicesOf(all);
    final groups = [
      for (final s in found)
        ServiceGroup(s.serviceUuid, [
          for (final info in s.characteristics)
            CharKey(CharacteristicRef(remoteId, s.serviceUuid, info.characteristicUuid), info.properties),
        ]),
    ];
    final keys = {for (final group in groups) ...group.chars};
    final missing = subscribed.where((k) => !keys.contains(k)).map((k) => k.name);
    if (missing.isNotEmpty) throw StateError('not found after discovery: ${missing.join(', ')}');

    state = groups;
    final hidden = all.length - found.length;
    Log.event(
      'Found ${found.length} services, ${keys.length} characteristics'
      '${hidden == 0 ? '' : ' ($hidden non-fixture services hidden)'}',
    );
  }
}
