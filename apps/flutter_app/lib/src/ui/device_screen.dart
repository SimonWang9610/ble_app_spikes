import 'package:ble_poc_dart/ble_poc_dart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../fixture.dart';
import '../session/session_bloc.dart';
import '../session/session_state.dart';
import 'characteristic_sheet.dart';

class DeviceScreen extends StatelessWidget {
  const DeviceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Rebuilds when the device's status or services change; rows rebuild on their own (below).
    return BlocBuilder<SessionBloc, SessionState>(
      buildWhen: (a, b) =>
          a.remoteId != b.remoteId ||
          a.status != b.status ||
          a.autoReconnect != b.autoReconnect ||
          a.rssi != b.rssi ||
          a.mtu != b.mtu ||
          a.services != b.services,
      builder: (context, s) {
        final bloc = context.read<SessionBloc>();
        return Scaffold(
          appBar: AppBar(title: Text(s.name)),
          body: s.remoteId == null
              ? const Center(child: Text('Not connected'))
              : ListView(
                  children: [
                    ListTile(
                      leading: Icon(Icons.circle, size: 12, color: _color(s.status)),
                      title: Text(s.status.text),
                      trailing: _StatusButton(status: s.status),
                    ),
                    SwitchListTile(
                      title: const Text('Auto-reconnect'),
                      value: s.autoReconnect,
                      onChanged: (on) => bloc.add(AutoReconnectToggled(on)),
                    ),
                    ListTile(
                      dense: true,
                      title: Text('RSSI ${s.rssi == null ? '–' : '${s.rssi} dBm'} · MTU ${s.mtu ?? '–'}'),
                      trailing: TextButton(
                        onPressed: s.isConnected ? () => bloc.add(const RssiRequested()) : null,
                        child: const Text('Refresh RSSI'),
                      ),
                    ),
                    for (final group in s.services) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                        child: Text(Fixture.label(group.uuid), style: Theme.of(context).textTheme.titleSmall),
                      ),
                      for (final key in group.keys) _CharacteristicRow(charKey: key),
                    ],
                  ],
                ),
        );
      },
    );
  }

  static Color _color(ConnectionStatus status) => switch (status) {
    Connected() => Colors.green,
    Connecting() || Reconnecting() || Disconnecting() => Colors.orange,
    Disconnected() => Colors.red,
  };
}

class _StatusButton extends StatelessWidget {
  const _StatusButton({required this.status});

  final ConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<SessionBloc>();
    return switch (status) {
      Connected() || Reconnecting() => TextButton(
        onPressed: () {
          bloc.add(const SessionDisconnectRequested());
          Navigator.of(context).pop();
        },
        child: const Text('Disconnect', style: TextStyle(color: Colors.red)),
      ),
      Disconnected() => TextButton(
        onPressed: () => bloc.add(const SessionConnectRequested()),
        child: const Text('Connect'),
      ),
      Connecting() ||
      Disconnecting() => const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
    };
  }
}

/// One characteristic row; `BlocSelector` rebuilds it only when this characteristic changes.
class _CharacteristicRow extends StatelessWidget {
  const _CharacteristicRow({required this.charKey});

  final String charKey;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<SessionBloc, SessionState, CharState?>(
      selector: (s) => s.chars[charKey],
      builder: (context, c) {
        if (c == null) return const SizedBox.shrink();
        final value = c.latest == null
            ? '–'
            : '${c.show(c.latest!)} · ${c.source!.name} ${c.latestTime!.toIso8601String().substring(11, 19)}';
        return ListTile(
          title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(
            '${describeProperties(c.properties)}\n$value',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'Menlo', fontSize: 12),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (c.subscribed) ...[
                const Icon(Icons.sensors, size: 16, color: Colors.green),
                Text(' ${c.receivedCount}', style: const TextStyle(color: Colors.green)),
              ],
              if (c.error != null) const Icon(Icons.error_outline, color: Colors.red),
              const Icon(Icons.chevron_right),
            ],
          ),
          onTap: () => showCharacteristicSheet(context, charKey),
        );
      },
    );
  }
}

String describeProperties(CharacteristicProperties p) => [
  if (p.read) 'read',
  if (p.write) 'write',
  if (p.writeWithoutResponse) 'write without response',
  if (p.notify) 'notify',
  if (p.indicate) 'indicate',
].join(' · ');
