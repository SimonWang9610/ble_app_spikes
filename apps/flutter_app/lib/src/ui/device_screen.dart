import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../fixture.dart';
import '../session/session_bloc.dart';
import '../session/session_state.dart';
import 'operation_sheet.dart';
import 'operation.dart';

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
                    for (final group in s.services) _ServiceCard(group: group, chars: s.chars),
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

/// One service: its name and UUID, then one row per (characteristic, operation).
class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.group, required this.chars});

  final ServiceGroup group;
  // Only read for each characteristic's properties, which don't change after discovery.
  final Map<String, CharState> chars;

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
          for (final key in group.keys)
            if (chars[key] case final c?)
              for (final op in Operation.of(c.properties)) _OperationRow(charKey: key, operation: op),
        ],
      ),
    );
  }
}

const _mono = TextStyle(fontFamily: 'Menlo', fontSize: 12);

/// One (characteristic, operation) row; `BlocSelector` rebuilds it only when this characteristic changes.
class _OperationRow extends StatelessWidget {
  const _OperationRow({required this.charKey, required this.operation});

  final String charKey;
  final Operation operation;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<SessionBloc, SessionState, CharState?>(
      selector: (s) => s.chars[charKey],
      builder: (context, c) {
        if (c == null) return const SizedBox.shrink();
        final name = Fixture.nameOf(c.ref.characteristic);
        return ListTile(
          title: Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (name != null) Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
              OperationChip(operation),
            ],
          ),
          subtitle: Text(c.ref.characteristic, maxLines: 2, overflow: TextOverflow.ellipsis, style: _mono),
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
      },
    );
  }
}
