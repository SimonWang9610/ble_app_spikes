import 'package:flutter_app/core/fixture/fixture.dart';
import 'package:flutter_app/features/nearby/application/nearby.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_ble.dart';

void main() {
  late FakeBle ble;
  late ProviderContainer container;
  late ProviderSubscription<NearbyState> screen;

  setUp(() {
    ble = FakeBle();
    container = ProviderContainer.test(overrides: ble.overrides);
    screen = container.listen(nearbyProvider, (_, _) {});
  });

  test('scans for fixtures and lists results by signal strength', () async {
    await container.read(nearbyProvider.notifier).setScanning(true);
    ble.scan.add([scanResult('far', -80), scanResult('near', -40)]);
    await pumpEventQueue();

    expect(ble.calls, ['startScan [${Fixture.name}]']);
    final state = container.read(nearbyProvider);
    expect(state.scanning, isTrue);
    expect(state.results.map((r) => r.remoteId), ['near', 'far']);
  });

  test('turning the filter off restarts the scan without names', () async {
    await container.read(nearbyProvider.notifier).setScanning(true);
    container.read(nearbyProvider.notifier).setOnlyFixtures(false);
    await pumpEventQueue();
    expect(ble.calls.last, 'startScan []');
  });

  test('stopping ends the scan', () async {
    await container.read(nearbyProvider.notifier).setScanning(true);
    await container.read(nearbyProvider.notifier).setScanning(false);
    expect(ble.calls.last, 'stopScan');
    expect(container.read(nearbyProvider).scanning, isFalse);
  });

  test('leaving the screen stops a running scan', () async {
    await container.read(nearbyProvider.notifier).setScanning(true);
    screen.close();
    await pumpEventQueue();
    expect(ble.calls.last, 'stopScan');
  });
}
