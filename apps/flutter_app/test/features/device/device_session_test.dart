import 'package:flutter_app/core/ble/characteristic_ref.dart';
import 'package:flutter_app/core/log/logger.dart';
import 'package:flutter_app/features/device/application/characteristic.dart';
import 'package:flutter_app/features/device/application/connection.dart';
import 'package:flutter_app/features/device/application/current_device.dart';
import 'package:flutter_app/features/device/application/device_session.dart';
import 'package:flutter_app/features/device/application/gatt.dart';
import 'package:flutter_app/features/device/application/subscriptions.dart';
import 'package:flutter_app/features/device/domain/char_key.dart';
import 'package:flutter_app/features/device/domain/char_state.dart';
import 'package:flutter_app/features/device/domain/connection_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_ble.dart';

void main() {
  late FakeBle ble;
  late ProviderContainer container;
  late List<String> log;

  DeviceSession session() => container.read(deviceSessionProvider.notifier);
  ConnectionStatus status() => container.read(connectionProvider).status;
  CharKey notifyKey() => CharKey(CharacteristicRef(deviceId, streamService, notifyUuid), props(notify: true));
  CharState char(CharKey key) => container.read(characteristicProvider(key));

  setUp(() {
    ble = FakeBle();
    container = ProviderContainer.test(overrides: ble.overrides);
    log = [];
    container.read(loggerProvider).entries.where((e) => e.kind != LogKind.api).listen((e) => log.add(e.text));
    container.listen(characteristicProvider(notifyKey()), (_, _) {});
  });

  Future<void> openAndSubscribe() async {
    await session().open(deviceId, 'Fixture');
    await container.read(subscriptionsProvider.notifier).set(notifyKey(), true);
  }

  test('open connects, shows only the fixture services and reads the MTU', () async {
    await session().open(deviceId, 'Fixture');
    await pumpEventQueue();

    expect(status(), isA<Connected>());
    expect(container.read(connectionProvider).mtu, 185);
    expect(container.read(gattProvider).map((g) => g.uuid), [dataService, streamService]);
    expect(log, [
      'Connecting to Fixture',
      'Found 2 services, 2 characteristics (1 non-fixture services hidden)',
      'Connected',
    ]);
  });

  test('a failed connect leaves the device current and Disconnected with the reason', () async {
    ble.connectFailures = 1;
    await session().open(deviceId, 'Fixture');

    expect(status(), isA<Disconnected>().having((s) => s.reason, 'reason', 'Bad state: connect failed'));
    expect(container.read(currentDeviceProvider)?.remoteId, deviceId);
  });

  test('subscribed values reach the characteristic', () async {
    await openAndSubscribe();
    ble
      ..push(notifyUuid, [1, 0, 0, 0])
      ..push(notifyUuid, [2, 0, 0, 0]);
    await pumpEventQueue();

    final c = char(notifyKey());
    expect(c.subscribed, isTrue);
    expect(c.receivedCount, 2);
    expect(c.source, ValueSource.received);
    expect(log, contains('NOTIFY received 02 00 00 00 = 2'));
  });

  test('a lost link reconnects and resumes the subscriptions', () async {
    await openAndSubscribe();
    ble.calls.clear();
    ble.dropLink(deviceId);
    await pumpEventQueue(times: 50);

    expect(status(), isA<Connected>());
    expect(ble.calls, ['connect $deviceId', 'discoverServices', 'setNotify NOTIFY true']);
    expect(
      log.where((l) => l.startsWith('Reconnected')).single,
      matches(r'^Reconnected after \d+\.\d s, resumed NOTIFY$'),
    );
  });

  test('without auto-reconnect a lost link ends the subscriptions', () async {
    await openAndSubscribe();
    container.read(connectionProvider.notifier).setAutoReconnect(false);
    ble.dropLink(deviceId);
    await pumpEventQueue();

    expect(status(), isA<Disconnected>().having((s) => s.reason, 'reason', 'link lost'));
    expect(char(notifyKey()).subscribed, isFalse);
  });

  test('disconnect unsubscribes, drops the link and forgets the device', () async {
    await openAndSubscribe();
    ble.calls.clear();
    await session().disconnect();
    await pumpEventQueue();

    expect(ble.calls, ['setNotify NOTIFY false', 'disconnect $deviceId', 'forget $deviceId']);
    expect(container.read(currentDeviceProvider), isNull);
    expect(container.read(connectionProvider).remoteId, isNull);
    expect(container.read(gattProvider), isEmpty);
    expect(log.last, 'Disconnected');
  });

  test('opening another device disconnects the current one first', () async {
    await session().open(deviceId, 'Fixture');
    await session().open('other', 'Other');

    expect(ble.calls, containsAllInOrder(['disconnect $deviceId', 'forget $deviceId', 'connect other']));
    expect(container.read(connectionProvider).name, 'Other');
  });
}
