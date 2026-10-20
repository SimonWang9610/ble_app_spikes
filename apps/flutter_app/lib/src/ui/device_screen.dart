import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../fixture.dart';
import '../session/characteristic.dart';
import '../session/connection.dart';
import '../session/device_session.dart';
import '../session/gatt.dart';
import 'operation_sheet.dart';
import 'operation.dart';

class DeviceScreen extends ConsumerWidget {
  const DeviceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Rebuilds when the link or the services change; rows rebuild on their own (below).
    final c = ref.watch(connectionProvider);
    final services = ref.watch(gattProvider);
    final connection = ref.read(connectionProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: Text(c.name)),
      body: c.remoteId == null
          ? const Center(child: Text('Not connected'))
          : ListView(
              children: [
                ListTile(
                  leading: Icon(Icons.circle, size: 12, color: _color(c.status)),
                  title: Text(c.status.text),
                  trailing: _StatusButton(status: c.status),
                ),
                SwitchListTile(
                  title: const Text('Auto-reconnect'),
                  value: c.autoReconnect,
                  onChanged: connection.setAutoReconnect,
                ),
                ListTile(
                  dense: true,
                  title: Text('RSSI ${c.rssi == null ? '–' : '${c.rssi} dBm'} · MTU ${c.mtu ?? '–'}'),
                  trailing: TextButton(
                    onPressed: c.isConnected ? connection.refreshRssi : null,
                    child: const Text('Refresh RSSI'),
                  ),
                ),
                for (final group in services) _ServiceCard(group: group),
              ],
            ),
    );
  }

  static Color _color(ConnectionStatus status) => switch (status) {
    Connected() => Colors.green,
    Connecting() || Reconnecting() || Disconnecting() => Colors.orange,
    Disconnected() => Colors.red,
  };
}

class _StatusButton extends ConsumerWidget {
  const _StatusButton({required this.status});

  final ConnectionStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.read(deviceSessionProvider.notifier);
    return switch (status) {
      Connected() || Reconnecting() => TextButton(
        onPressed: () {
          session.disconnect();
          Navigator.of(context).pop();
        },
        child: const Text('Disconnect', style: TextStyle(color: Colors.red)),
      ),
      Disconnected() => TextButton(onPressed: session.connect, child: const Text('Connect')),
      Connecting() ||
      Disconnecting() => const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
    };
  }
}

/// One service: its name and UUID, then one row per (characteristic, operation).
class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.group});

  final ServiceGroup group;

  @override
  Widget build(BuildContext context) {
    final name = Fixture.nameOf(group.uuid);
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (name != null) Text(name, style: Theme.of(context).textTheme.titleSmall),
                Text(group.uuid, style: _mono.copyWith(color: Colors.grey)),
              ],
            ),
          ),
          for (final key in group.chars)
            for (final op in Operation.of(key.properties)) _OperationRow(charKey: key, operation: op),
        ],
      ),
    );
  }
}

const _mono = TextStyle(fontFamily: 'Menlo', fontSize: 12);

/// One (characteristic, operation) row; watches only its characteristic, so it rebuilds alone.
class _OperationRow extends ConsumerWidget {
  const _OperationRow({required this.charKey, required this.operation});

  final CharKey charKey;
  final Operation operation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(characteristicProvider(charKey));
    final name = Fixture.nameOf(charKey.ref.characteristic);
    return ListTile(
      title: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (name != null) Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
          OperationChip(operation),
        ],
      ),
      subtitle: Text(charKey.ref.characteristic, maxLines: 2, overflow: TextOverflow.ellipsis, style: _mono),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (operation.isSubscription)
            c.subscribed
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sensors, size: 18, color: Colors.green),
                      Text(' ${c.receivedCount}', style: const TextStyle(color: Colors.green)),
                    ],
                  )
                : const Icon(Icons.sensors_off, size: 18, color: Colors.grey),
          if (c.error != null) const Icon(Icons.error_outline, color: Colors.red),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () => showOperationSheet(context, charKey, operation),
    );
  }
}
