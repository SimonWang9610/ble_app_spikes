import 'dart:async';
import 'dart:typed_data';

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
  CharKey valueKey() =>
      CharKey(CharacteristicRef(deviceId, dataService, valueUuid), props(read: true, write: true, notify: true));
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
      'VALUE subscribed',
      'Connected',
    ]);
  });

  test('VALUE is subscribed at connect and a write comes back as its echo', () async {
    await session().open(deviceId, 'Fixture');
    container.listen(characteristicProvider(valueKey()), (_, _) {});
    await container
        .read(characteristicProvider(valueKey()).notifier)
        .write(Uint8List.fromList('hi'.codeUnits), withoutResponse: false);
    await pumpEventQueue();

    final c = char(valueKey());
    expect(c.subscribed, isTrue);
    expect(c.receivedCount, 1);
    expect(c.source, ValueSource.received);
    expect(c.latest, 'echo: hi'.codeUnits);
    expect(log, contains('VALUE received 65 63 68 6f 3a 20 68 69 "echo: hi"'));
  });

  test('a failed subscribe at connect is logged and the write still goes', () async {
    ble.failNotify = true;
    await session().open(deviceId, 'Fixture');
    await container
        .read(characteristicProvider(valueKey()).notifier)
        .write(Uint8List.fromList([1]), withoutResponse: false);
    await pumpEventQueue();

    expect(status(), isA<Connected>());
    expect(char(valueKey()).subscribed, isFalse);
    expect(log, contains('VALUE: subscribe failed: Bad state: notify failed'));
    expect(ble.calls, contains('write VALUE [1]'));
  });

  test('a link lost while subscribing at connect starts a reconnect', () async {
    final held = ble.holdNotify = Completer<void>();
    final opening = session().open(deviceId, 'Fixture');
    await pumpEventQueue();
    ble.dropLink(deviceId);
    await pumpEventQueue();
    held.complete();
    await opening;
    await pumpEventQueue(times: 50);

    expect(status(), isA<Connected>());
    expect(log, containsAllInOrder([startsWith('Link lost after'), startsWith('Reconnected after')]));
  });

  test('Disconnect during the subscribe at connect logs nothing after Disconnected', () async {
    final held = ble.holdNotify = Completer<void>();
    final opening = session().open(deviceId, 'Fixture');
    await pumpEventQueue();
    await session().disconnect();
    held.complete();
    await opening;
    await pumpEventQueue();

    expect(log.last, 'Disconnected');
  });

  test('only notify-only characteristics show 4-byte values as counters', () {
    expect(valueKey().show([1, 2, 3, 4]), '01 02 03 04');
    expect(notifyKey().show([1, 0, 0, 0]), '01 00 00 00 = 1');
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
    expect(ble.calls, ['connect $deviceId', 'discoverServices', 'setNotify VALUE true', 'setNotify NOTIFY true']);
    expect(
      log.where((l) => l.startsWith('Reconnected')).single,
      matches(r'^Reconnected after \d+\.\d s, resumed NOTIFY, VALUE$'),
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

    expect(ble.calls, ['setNotify VALUE false', 'setNotify NOTIFY false', 'disconnect $deviceId', 'forget $deviceId']);
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

  test('opening the same device after a failed connect connects again', () async {
    ble.connectFailures = 1;
    await session().open(deviceId, 'Fixture');
    await session().open(deviceId, 'Fixture');

    expect(status(), isA<Connected>());
  });

  test('while reconnecting, values stop and Disconnect ends the retries', () async {
    await openAndSubscribe();
    ble.connectFailures = 1000;
    // The value lands right behind the loss, before the first retry fails.
    ble
      ..dropLink(deviceId)
      ..push(notifyUuid, [9, 0, 0, 0]);
    await pumpEventQueue();
    expect(status(), isA<Reconnecting>());
    expect(char(notifyKey()).receivedCount, 0);

    await session().disconnect();
    final attempts = ble.calls.where((c) => c.startsWith('connect')).length;
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    expect(ble.calls.where((c) => c.startsWith('connect')), hasLength(attempts));
    expect(container.read(currentDeviceProvider), isNull);
  });

  test('a characteristic keeps its value while nothing shows it', () async {
    await session().open(deviceId, 'Fixture');
    final row = container.listen(characteristicProvider(valueKey()), (_, _) {});
    await container.read(characteristicProvider(valueKey()).notifier).read();
    row.close();
    await pumpEventQueue();

    expect(container.read(characteristicProvider(valueKey())).latest, [0x68, 0x69]);
  });

  test('a slow Disconnect stops the retries before the link is down', () async {
    await openAndSubscribe();
    ble.connectFailures = 1000;
    ble.dropLink(deviceId);
    await pumpEventQueue();
    final attempts = ble.calls.where((c) => c.startsWith('connect')).length;

    // Longer than the first backoff, so only Disconnect itself can stop the loop.
    ble.disconnectDelay = const Duration(milliseconds: 1500);
    await session().disconnect();
    await pumpEventQueue();

    expect(ble.calls.where((c) => c.startsWith('connect')), hasLength(attempts));
    expect(log, isNot(contains('Reconnecting, attempt 2')));
  });

  test('a reconnect that lands during Disconnect is dropped', () async {
    await openAndSubscribe();
    final statuses = <ConnectionStatus>[];
    container.listen(connectionProvider.select((c) => c.status), (_, s) => statuses.add(s));
    final held = ble.holdConnect = Completer<void>();
    ble.dropLink(deviceId);
    await pumpEventQueue();

    ble.disconnectDelay = const Duration(milliseconds: 300);
    final disconnecting = session().disconnect();
    await pumpEventQueue();
    held.complete();
    await disconnecting;
    await pumpEventQueue();

    expect(statuses.skipWhile((s) => s is! Disconnecting).whereType<Connected>(), isEmpty);
    expect(log.where((l) => l.startsWith('Reconnected')), isEmpty);
  });
}
