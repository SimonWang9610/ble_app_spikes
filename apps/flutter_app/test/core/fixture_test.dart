import 'package:flutter_app/core/fixture/fixture.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_ble.dart';

void main() {
  test('servicesOf keeps only fixture services when there are any', () {
    final all = fixtureServices(deviceId);
    expect(Fixture.servicesOf(all).map((s) => s.serviceUuid), [dataService, streamService]);
    expect(Fixture.servicesOf(all.sublist(2)), hasLength(1));
  });

  test('names fixture UUIDs and shortens others', () {
    expect(Fixture.nameOf(valueUuid), 'VALUE');
    expect(Fixture.nameOf('0000180a-0000-1000-8000-00805f9b34fb'), isNull);
    expect(Fixture.shortName('0000180a-0000-1000-8000-00805f9b34fb'), '0000180a…');
    expect(Fixture.label(valueUuid), 'VALUE (f0e10001…)');
  });
}
