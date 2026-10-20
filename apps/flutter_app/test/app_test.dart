import 'package:ble_poc_dart/ble_poc_dart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_ble.dart';

/// Runs pending work and lets route and sheet transitions finish; the scan spinner never settles.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(pumpEventQueue);
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  late FakeBle ble;

  Future<void> startApp(WidgetTester tester) async {
    ble = FakeBle();
    await tester.pumpWidget(ProviderScope(overrides: ble.overrides, child: const BlePocApp()));
    await settle(tester);
  }

  Future<void> openFixture(WidgetTester tester) async {
    ble.scan.add([scanResult(deviceId, -50)]);
    await tester.pump();
    await tester.tap(find.text('HM-BLE-FIXTURE'));
    await settle(tester);
  }

  testWidgets('Nearby scans once Bluetooth is ready and lists the fixture', (tester) async {
    await startApp(tester);
    ble.scan.add([scanResult(deviceId, -50)]);
    await tester.pump();

    expect(ble.calls, ['initialize', 'startScan [HM-BLE-FIXTURE]']);
    expect(find.text('HM-BLE-FIXTURE'), findsOneWidget);
    expect(find.text('-50 dBm'), findsOneWidget);
  });

  testWidgets('Nearby warns when Bluetooth is off', (tester) async {
    await startApp(tester);
    ble.adapter.add(BluetoothAdapterState.poweredOff);
    await tester.pump();

    expect(find.text('Bluetooth is off'), findsOneWidget);
    // The log panel's collapsed line shows the latest event.
    expect(find.textContaining('Bluetooth poweredOff'), findsOneWidget);
  });

  testWidgets('opening a device connects and shows its operations', (tester) async {
    await startApp(tester);
    await openFixture(tester);

    expect(ble.calls, contains('stopScan'));
    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('RSSI – · MTU 185'), findsOneWidget);
    expect(find.text('VALUE'), findsNWidgets(2)); // read and write rows
    expect(find.text('NOTIFY'), findsOneWidget);
    expect(find.text('180a'), findsNothing);
  });

  testWidgets('the read sheet reads and shows the value', (tester) async {
    await startApp(tester);
    await openFixture(tester);
    await tester.tap(find.widgetWithText(ListTile, 'read'));
    await settle(tester);
    expect(find.text('No value yet'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Read'));
    await settle(tester);

    expect(ble.calls, contains('read VALUE'));
    expect(find.text('68 69 "hi"'), findsOneWidget);
  });

  testWidgets('the write sheet rejects bad hex and acknowledges a write', (tester) async {
    await startApp(tester);
    await openFixture(tester);
    await tester.tap(find.widgetWithText(ListTile, 'write'));
    await settle(tester);

    await tester.enterText(find.byType(TextField), 'zz');
    await tester.tap(find.widgetWithText(FilledButton, 'Write'));
    await tester.pump();
    expect(find.text('not hex: zz'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '01 02');
    await tester.tap(find.widgetWithText(FilledButton, 'Write'));
    await settle(tester);
    expect(ble.calls, contains('write VALUE [1, 2]'));
    expect(find.textContaining('✓ Acknowledged'), findsOneWidget);
  });

  testWidgets('Disconnect returns to Nearby and resumes scanning', (tester) async {
    await startApp(tester);
    await openFixture(tester);
    ble.calls.clear();

    await tester.tap(find.text('Disconnect'));
    await settle(tester);

    expect(find.text('Nearby'), findsWidgets);
    expect(ble.calls, containsAll(['disconnect $deviceId', 'forget $deviceId', 'startScan [HM-BLE-FIXTURE]']));
    expect(find.text('Connected'), findsNothing);
  });
}
