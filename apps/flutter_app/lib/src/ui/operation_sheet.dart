import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bytes.dart';
import '../fixture.dart';
import '../session/session_bloc.dart';
import '../session/session_state.dart';
import 'operation.dart';

Future<void> showOperationSheet(BuildContext context, String key, Operation operation) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => OperationSheet(charKey: key, operation: operation),
  );
}

/// The dialog for one operation of one characteristic.
/// The write form (text, format) is UI state, so it stays in this widget.
class OperationSheet extends StatefulWidget {
  const OperationSheet({super.key, required this.charKey, required this.operation});

  final String charKey;
  final Operation operation;

  @override
  State<OperationSheet> createState() => _OperationSheetState();
}

class _OperationSheetState extends State<OperationSheet> {
  static const _mono = TextStyle(fontFamily: 'Menlo');
  static const _muted = TextStyle(fontSize: 12, color: Colors.grey);

  final _input = TextEditingController();
  ValueFormat _format = ValueFormat.hex;
  String? _inputError;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _write() {
    try {
      final value = parseValue(_input.text, _format);
      setState(() => _inputError = null);
      context.read<SessionBloc>().add(
        WriteRequested(widget.charKey, value, withoutResponse: widget.operation == Operation.writeWithoutResponse),
      );
    } on FormatException catch (e) {
      setState(() => _inputError = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connected = context.select<SessionBloc, bool>((b) => b.state.isConnected);
    return BlocSelector<SessionBloc, SessionState, CharState?>(
      selector: (s) => s.chars[widget.charKey],
      builder: (context, c) {
        if (c == null) return const SizedBox(height: 120, child: Center(child: Text('Not connected')));
        final enabled = connected && c.busy == null;
        final name = Fixture.nameOf(c.ref.characteristic);

        return Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (name != null) Text(name, style: Theme.of(context).textTheme.titleLarge),
                  OperationChip(widget.operation),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${c.ref.characteristic}\n${Fixture.label(c.ref.service)}',
                style: _mono.copyWith(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ...switch (widget.operation) {
                Operation.read => _read(c, enabled),
                Operation.write || Operation.writeWithoutResponse => _writeForm(enabled),
                Operation.notify || Operation.indicate => _subscription(c, enabled),
              },
              if (c.busy != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(c.busy!)),
              if (c.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SelectableText(c.error!, style: const TextStyle(color: Colors.red)),
                ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _read(CharState c, bool enabled) => [
    Text('Latest', style: Theme.of(context).textTheme.labelLarge),
    if (c.latest == null)
      const Text('No value yet', style: TextStyle(color: Colors.grey))
    else ...[
      SelectableText(c.show(c.latest!), style: _mono),
      Text('${c.source!.name} at ${_time(c.latestTime!)}', style: _muted),
    ],
    const SizedBox(height: 12),
    FilledButton.tonal(
      onPressed: enabled ? () => context.read<SessionBloc>().add(ReadRequested(widget.charKey)) : null,
      child: const Text('Read'),
    ),
  ];

  List<Widget> _writeForm(bool enabled) => [
    Row(
      children: [
        SegmentedButton<ValueFormat>(
          segments: const [
            ButtonSegment(value: ValueFormat.hex, label: Text('hex')),
            ButtonSegment(value: ValueFormat.utf8, label: Text('text')),
          ],
          selected: {_format},
          onSelectionChanged: (s) => setState(() => _format = s.single),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: _input,
            autocorrect: false,
            style: _mono,
            decoration: InputDecoration(
              hintText: _format == ValueFormat.hex ? '01 02 0a' : 'text',
              errorText: _inputError,
            ),
          ),
        ),
      ],
    ),
    const SizedBox(height: 12),
    FilledButton.tonal(onPressed: enabled ? _write : null, child: const Text('Write')),
  ];

  List<Widget> _subscription(CharState c, bool enabled) {
    final bloc = context.read<SessionBloc>();
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
              onPressed: enabled ? () => bloc.add(SubscribeRequested(widget.charKey, on: false)) : null,
              child: const Text('Unsubscribe'),
            )
          : FilledButton(
              onPressed: enabled ? () => bloc.add(SubscribeRequested(widget.charKey, on: true)) : null,
              child: const Text('Subscribe'),
            ),
      const Text('Stays on when you leave the device; ends on Unsubscribe or Disconnect.', style: _muted),
    ];
  }

  static String _time(DateTime t) => t.toIso8601String().substring(11, 19);
}
