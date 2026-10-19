import 'package:ble_poc_dart/ble_poc_dart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../adapter/adapter_cubit.dart';
import '../nearby/nearby_bloc.dart';
import '../session/session_bloc.dart';
import '../session/session_state.dart';
import 'device_screen.dart';

class NearbyScreen extends StatefulWidget {
  const NearbyScreen({super.key});

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen> {
  @override
  void initState() {
    super.initState();
    if (context.read<AdapterCubit>().state.initialized) _scan(true);
  }

  void _scan(bool active) => context.read<NearbyBloc>().add(NearbyScanSet(active));

  /// Scanning pauses while the Device screen is on top and resumes when it is popped.
  Future<void> _openDevice(String remoteId, String name) async {
    context.read<SessionBloc>().add(SessionOpened(remoteId, name));
    _scan(false);
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DeviceScreen()));
    if (mounted && context.read<AdapterCubit>().state.initialized) _scan(true);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AdapterCubit, AdapterState>(
      // Start scanning once the manager is ready.
      listenWhen: (a, b) => !a.initialized && b.initialized,
      listener: (context, _) => _scan(true),
      child: Scaffold(
        appBar: AppBar(title: const Text('Nearby')),
        body: ListView(
          children: [
            const _BluetoothBanner(),
            _ConnectedSection(onOpen: _openDevice),
            BlocBuilder<NearbyBloc, NearbyState>(
              builder: (context, nearby) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header('Nearby', trailing: nearby.scanning ? const _Spinner() : null),
                  SwitchListTile(
                    title: const Text('Only HM-BLE fixtures'),
                    value: nearby.onlyFixtures,
                    onChanged: (on) => context.read<NearbyBloc>().add(NearbyFilterChanged(on)),
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
            ),
          ],
        ),
      ),
    );
  }
}

class _BluetoothBanner extends StatelessWidget {
  const _BluetoothBanner();

  @override
  Widget build(BuildContext context) {
    final adapter = context.watch<AdapterCubit>().state;
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

class _ConnectedSection extends StatelessWidget {
  const _ConnectedSection({required this.onOpen});

  final void Function(String remoteId, String name) onOpen;

  @override
  Widget build(BuildContext context) {
    // Rebuilds only when the connected device or its status changes, not on every value.
    final (remoteId, name, status) = context.select<SessionBloc, (String?, String, ConnectionStatus)>(
      (b) => (b.state.remoteId, b.state.name, b.state.status),
    );
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
