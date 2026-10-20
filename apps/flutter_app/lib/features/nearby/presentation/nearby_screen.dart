import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_app/core/ble/adapter.dart';
import 'package:flutter_app/core/theme/app_colors.dart';
import 'package:flutter_app/core/widgets/small_spinner.dart';
import 'package:flutter_app/features/device/application/device_session.dart';
import 'package:flutter_app/features/device/presentation/device_screen.dart';
import 'package:flutter_app/features/nearby/application/nearby.dart';
import 'package:flutter_app/features/nearby/presentation/widgets/bluetooth_banner.dart';
import 'package:flutter_app/features/nearby/presentation/widgets/connected_section.dart';
import 'package:flutter_app/features/nearby/presentation/widgets/device_tile.dart';
import 'package:flutter_app/features/nearby/presentation/widgets/section_header.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NearbyScreen extends ConsumerStatefulWidget {
  const NearbyScreen({super.key});

  @override
  ConsumerState<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends ConsumerState<NearbyScreen> {
  @override
  void initState() {
    super.initState();
    // Outside this build: providers can't change while the tree is building.
    Future.microtask(() {
      if (mounted && ref.read(adapterProvider).initialized) _scan(true);
    });
  }

  void _scan(bool active) => unawaited(ref.read(nearbyProvider.notifier).setScanning(active));

  /// Scanning pauses while the Device screen is on top and resumes when it is popped.
  Future<void> _openDevice(String remoteId, String name) async {
    unawaited(ref.read(deviceSessionProvider.notifier).open(remoteId, name));
    _scan(false);
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DeviceScreen()));
    if (mounted && ref.read(adapterProvider).initialized) _scan(true);
  }

  @override
  Widget build(BuildContext context) {
    // Start scanning once the manager is ready.
    ref.listen(adapterProvider.select((a) => a.initialized), (was, now) {
      if (was != true && now) _scan(true);
    });
    final nearby = ref.watch(nearbyProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Nearby')),
      body: ListView(
        children: [
          const BluetoothBanner(),
          ConnectedSection(onOpen: _openDevice),
          SectionHeader('Nearby', trailing: nearby.scanning ? const SmallSpinner() : null),
          SwitchListTile(
            title: const Text('Only HM-BLE fixtures'),
            value: nearby.onlyFixtures,
            onChanged: ref.read(nearbyProvider.notifier).setOnlyFixtures,
          ),
          for (final result in nearby.results)
            DeviceTile(
              name: result.advertisementData.advName,
              detail: result.remoteId,
              trailing: '${result.rssi} dBm',
              onTap: () => _openDevice(result.remoteId, result.advertisementData.advName),
            ),
          if (nearby.error != null)
            ListTile(
              title: Text(nearby.error!, style: TextStyle(color: context.appColors.danger)),
            )
          else if (nearby.results.isEmpty && nearby.scanning)
            const ListTile(title: Text('Looking for devices…')),
        ],
      ),
    );
  }
}
