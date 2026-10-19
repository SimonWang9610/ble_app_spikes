import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bytes.dart';
import '../fixture.dart';
import '../session/session_bloc.dart';
import '../session/session_state.dart';
import 'device_screen.dart';

Future<void> showCharacteristicSheet(BuildContext context, String key) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => CharacteristicSheet(charKey: key),
  );
}

/// The dialog for one characteristic: only the actions its properties allow.
/// The write form (text, format, without response) is UI state, so it stays in this widget.
class CharacteristicSheet extends StatefulWidget {
  const CharacteristicSheet({super.key, required this.charKey});

  final String charKey;

  @override
  State<CharacteristicSheet> createState() => _CharacteristicSheetState();
}

class _CharacteristicSheetState extends State<CharacteristicSheet> {
  final _input = TextEditingController();
  ValueFormat _format = ValueFormat.hex;
  bool? _withoutResponse;
  String? _inputError;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _write(CharState c, bool withoutResponse) {
    try {
      final value = parseValue(_input.text, _format);
      setState(() => _inputError = null);
      context.read<SessionBloc>().add(WriteRequested(widget.charKey, value, withoutResponse: withoutResponse));
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
        final bloc = context.read<SessionBloc>();
        final p = c.properties;
        final withoutResponse = _withoutResponse ?? (!p.write && p.writeWithoutResponse);
        final mono = const TextStyle(fontFamily: 'Menlo');

        return Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(c.name, style: Theme.of(context).textTheme.titleLarge),
              Text(
                '${c.ref.characteristic}\n${Fixture.label(c.ref.service)} · ${describeProperties(p)}',
                style: mono.copyWith(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Text('Latest', style: Theme.of(context).textTheme.labelLarge),
              if (c.latest == null)
                const Text('No value yet', style: TextStyle(color: Colors.grey))
              else ...[
                SelectableText(c.show(c.latest!), style: mono),
                Text(
                  '${c.source!.name} at ${c.latestTime!.toIso8601String().substring(11, 19)}'
                  '${c.receivedCount > 0 ? ', ${c.receivedCount} received' : ''}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
              const SizedBox(height: 12),
              if (p.read)
                FilledButton.tonal(
                  onPressed: connected && c.busy == null ? () => bloc.add(ReadRequested(widget.charKey)) : null,
                  child: const Text('Read'),
                ),
              if (c.canWrite) ...[
                const SizedBox(height: 12),
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
                        style: mono,
                        decoration: InputDecoration(
                          hintText: _format == ValueFormat.hex ? '01 02 0a' : 'text',
                          errorText: _inputError,
                        ),
                      ),
                    ),
                  ],
                ),
                if (p.write && p.writeWithoutResponse)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Without response'),
                    value: withoutResponse,
                    onChanged: (v) => setState(() => _withoutResponse = v),
                  ),
                FilledButton.tonal(
                  onPressed: connected && c.busy == null ? () => _write(c, withoutResponse) : null,
                  child: const Text('Write'),
                ),
              ],
              if (c.canSubscribe) ...[
                const SizedBox(height: 12),
                c.subscribed
                    ? OutlinedButton(
                        onPressed: connected && c.busy == null
                            ? () => bloc.add(SubscribeRequested(widget.charKey, on: false))
                            : null,
                        child: const Text('Unsubscribe'),
                      )
                    : FilledButton(
                        onPressed: connected && c.busy == null
                            ? () => bloc.add(SubscribeRequested(widget.charKey, on: true))
                            : null,
                        child: const Text('Subscribe'),
                      ),
                const Text(
                  'Stays on when you leave the device; ends on Unsubscribe or Disconnect.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
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
}
