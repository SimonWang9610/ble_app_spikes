import 'package:ble_poc_dart/ble_poc_dart.dart';
import 'package:flutter_app/core/ble/ble_service.dart';
import 'package:flutter_app/core/fixture/fixture.dart';
import 'package:flutter_app/core/log/logger.dart';
import 'package:flutter_app/features/device/application/current_device.dart';
import 'package:flutter_app/features/device/domain/char_key.dart';
import 'package:flutter_app/features/device/domain/service_group.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'gatt.g.dart';

/// What the current device offers, as service tiles. The characteristics' own state lives in
/// `characteristicProvider`, keyed so that it survives rediscovery.
@Riverpod(keepAlive: true)
class Gatt extends _$Gatt {
  late Logger _log;

  @override
  List<ServiceGroup> build() {
    _log = ref.watch(loggerProvider);
    ref.watch(currentDeviceProvider);
    return const [];
  }

  Future<List<BluetoothService>> discover(String remoteId) {
    final link = ref.read(deviceLinkProvider);
    return _log.api('discoverServices()', () => link.discoverServices(remoteId));
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
    _log.event(
      'Found ${found.length} services, ${keys.length} characteristics'
      '${hidden == 0 ? '' : ' ($hidden non-fixture services hidden)'}',
    );
  }
}
