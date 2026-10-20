import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../fixture.dart';
import '../session/characteristic.dart';
import '../session/connection.dart';
import '../session/subscriptions.dart';
import 'operation.dart';
import 'write_form.dart';

/// Sized to its content, up to 90% of the screen, so the controls fit without scrolling.
Future<void> showOperationSheet(BuildContext context, CharKey key, Operation operation) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
    builder: (_) => OperationSheet(charKey: key, operation: operation),
  );
}

/// The dialog for one operation of one characteristic.
class OperationSheet extends ConsumerWidget {
  const OperationSheet({super.key, required this.charKey, required this.operation});

  static const _mono = TextStyle(fontFamily: 'Menlo');
  static const _muted = TextStyle(fontSize: 12, color: Colors.grey);

  final CharKey charKey;
  final Operation operation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connected = ref.watch(connectionProvider.select((c) => c.isConnected));
    final c = ref.watch(characteristicProvider(charKey));
    final enabled = connected && c.busy == null;
    final name = Fixture.nameOf(charKey.ref.characteristic);
    final isWrite = operation == Operation.write || operation == Operation.writeWithoutResponse;

    // Scrolls only if the keyboard leaves too little room.
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (name != null) Text(name, style: Theme.of(context).textTheme.titleLarge),
              OperationChip(operation),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${charKey.ref.characteristic}\n${Fixture.label(charKey.ref.service)}',
            style: _mono.copyWith(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ...switch (operation) {
            Operation.read => _read(context, ref, c, enabled),
            Operation.write || Operation.writeWithoutResponse => [
              WriteForm(
                charKey: charKey,
                withoutResponse: operation == Operation.writeWithoutResponse,
                enabled: enabled,
              ),
            ],
            Operation.notify || Operation.indicate => _subscription(context, ref, c, enabled),
          },
          if (c.busy != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(c.busy!)),
          // A write shows its own error under the Write button.
          if (c.error != null && !isWrite)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SelectableText(c.error!, style: const TextStyle(color: Colors.red)),
            ),
        ],
      ),
    );
  }

  List<Widget> _read(BuildContext context, WidgetRef ref, CharState c, bool enabled) => [
    Text('Latest', style: Theme.of(context).textTheme.labelLarge),
    if (c.latest == null)
      const Text('No value yet', style: TextStyle(color: Colors.grey))
    else ...[
      SelectableText(c.show(c.latest!), style: _mono),
      Text('${c.source!.name} at ${_time(c.latestTime!)}', style: _muted),
    ],
    const SizedBox(height: 12),
    FilledButton.tonal(
      onPressed: enabled ? ref.read(characteristicProvider(charKey).notifier).read : null,
      child: const Text('Read'),
    ),
  ];

  List<Widget> _subscription(BuildContext context, WidgetRef ref, CharState c, bool enabled) {
    final subscriptions = ref.read(subscriptionsProvider.notifier);
    final received = c.source == ValueSource.received ? c.latest : null;
    return [
      Row(
        children: [
          Icon(
            c.subscribed ? Icons.sensors : Icons.sensors_off,
            size: 18,
            color: c.subscribed ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 6),
          Text('${c.subscribed ? 'Subscribed' : 'Not subscribed'} · ${c.receivedCount} received'),
        ],
      ),
      const SizedBox(height: 12),
      Text('Latest received', style: Theme.of(context).textTheme.labelLarge),
      if (received == null)
        const Text('Nothing received yet', style: TextStyle(color: Colors.grey))
      else ...[
        SelectableText(c.show(received), style: _mono),
        Text('at ${_time(c.latestTime!)}', style: _muted),
      ],
      const SizedBox(height: 12),
      c.subscribed
          ? OutlinedButton(
              onPressed: enabled ? () => subscriptions.set(charKey, false) : null,
              child: const Text('Unsubscribe'),
            )
          : FilledButton(
              onPressed: enabled ? () => subscriptions.set(charKey, true) : null,
              child: const Text('Subscribe'),
            ),
      const Text('Stays on when you leave the device; ends on Unsubscribe or Disconnect.', style: _muted),
    ];
  }

  static String _time(DateTime t) => t.toIso8601String().substring(11, 19);
}
