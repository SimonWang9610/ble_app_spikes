import 'package:ble_poc_dart/ble_poc_dart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../adapter/adapter.dart';
import '../nearby/nearby.dart';
import '../session/connection.dart';
import '../session/device_session.dart';
import 'device_screen.dart';

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

  void _scan(bool active) => ref.read(nearbyProvider.notifier).setScanning(active);

  /// Scanning pauses while the Device screen is on top and resumes when it is popped.
  Future<void> _openDevice(String remoteId, String name) async {
    ref.read(deviceSessionProvider.notifier).open(remoteId, name);
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
          const _BluetoothBanner(),
          _ConnectedSection(onOpen: _openDevice),
          _Header('Nearby', trailing: nearby.scanning ? const _Spinner() : null),
          SwitchListTile(
            title: const Text('Only HM-BLE fixtures'),
            value: nearby.onlyFixtures,
            onChanged: ref.read(nearbyProvider.notifier).setOnlyFixtures,
          ),
          for (final result in nearby.results)
            _DeviceTile(
              name: result.advertisementData.advName,
              detail: result.remoteId,
              trailing: '${result.rssi} dBm',
              onTap: () => _openDevice(result.remoteId, result.advertisementData.advName),
            ),
          if (nearby.error != null)
            ListTile(
              title: Text(nearby.error!, style: const TextStyle(color: Colors.red)),
            )
          else if (nearby.results.isEmpty && nearby.scanning)
            const ListTile(title: Text('Looking for devices…')),
        ],
      ),
    );
  }
}

class _BluetoothBanner extends ConsumerWidget {
  const _BluetoothBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adapter = ref.watch(adapterProvider);
    final String? text;
    if (adapter.error != null) {
      text = 'Bluetooth unavailable: ${adapter.error}';
    } else if (adapter.bluetooth != null && adapter.bluetooth != BluetoothAdapterState.poweredOn) {
      text = adapter.bluetooth == BluetoothAdapterState.poweredOff ? 'Bluetooth is off' : 'Bluetooth is not ready';
    } else {
      text = null;
    }
    if (text == null) return const SizedBox.shrink();
    return ListTile(
      leading: const Icon(Icons.warning_amber, color: Colors.orange),
      title: Text(text, style: const TextStyle(color: Colors.orange)),
    );
  }
}

class _ConnectedSection extends ConsumerWidget {
  const _ConnectedSection({required this.onOpen});

  final void Function(String remoteId, String name) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Rebuilds only when the connected device or its status changes, not on RSSI or MTU.
    final (remoteId, name, status) = ref.watch(connectionProvider.select((c) => (c.remoteId, c.name, c.status)));
    if (remoteId == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Header('Connected'),
        _DeviceTile(name: name, detail: status.text, onTap: () => onOpen(remoteId, name)),
      ],
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.name, required this.detail, required this.onTap, this.trailing});

  final String name;
  final String detail;
  final String? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(name.isEmpty ? '(no name)' : name),
      subtitle: Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [if (trailing != null) Text(trailing!), const Icon(Icons.chevron_right)],
      ),
      onTap: onTap,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text, {this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Text(text, style: Theme.of(context).textTheme.titleSmall),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) =>
      const SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2));
}
