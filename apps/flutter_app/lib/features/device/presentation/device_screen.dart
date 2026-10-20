import 'package:flutter/material.dart';
import 'package:flutter_app/core/theme/app_colors.dart';
import 'package:flutter_app/features/device/application/connection.dart';
import 'package:flutter_app/features/device/application/gatt.dart';
import 'package:flutter_app/features/device/presentation/widgets/service_card.dart';
import 'package:flutter_app/features/device/presentation/widgets/status_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DeviceScreen extends ConsumerWidget {
  const DeviceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Rebuilds when the link or the services change; rows rebuild on their own.
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
                  leading: Icon(Icons.circle, size: 12, color: c.status.color(context.appColors)),
                  title: Text(c.status.text),
                  trailing: StatusButton(status: c.status),
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
                for (final group in services) ServiceCard(group: group),
              ],
            ),
    );
  }
}
