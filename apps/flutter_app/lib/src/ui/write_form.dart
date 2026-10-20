import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ble/ble_service.dart';
import '../bytes.dart';
import '../session/characteristic.dart';

/// The result of the last write made from this form.
typedef _WriteResult = ({DateTime time, String value, String? error});

/// Value input, Write button and the last write's result. All of it is UI state, so it stays here.
class WriteForm extends ConsumerStatefulWidget {
  const WriteForm({super.key, required this.charKey, required this.withoutResponse, required this.enabled});

  final CharKey charKey;
  final bool withoutResponse;
  final bool enabled;

  @override
  ConsumerState<WriteForm> createState() => _WriteFormState();
}

class _WriteFormState extends ConsumerState<WriteForm> {
  static const _mono = TextStyle(fontFamily: 'Menlo');

  final _input = TextEditingController();
  ValueFormat _format = ValueFormat.hex;
  String? _inputError;
  _WriteResult? _last;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _write() async {
    final key = widget.charKey;
    final Uint8List value;
    try {
      value = parseValue(_input.text, _format);
    } on FormatException catch (e) {
      setState(() => _inputError = e.message);
      return;
    }
    setState(() => _inputError = null);
    String? error;
    try {
      await ref.read(characteristicProvider(key).notifier).write(value, withoutResponse: widget.withoutResponse);
    } catch (e) {
      error = describeError(e);
    }
    if (mounted) setState(() => _last = (time: DateTime.now(), value: key.show(value), error: error));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        FilledButton.tonal(onPressed: widget.enabled ? _write : null, child: const Text('Write')),
        if (_last case final last?) Padding(padding: const EdgeInsets.only(top: 8), child: _result(last)),
      ],
    );
  }

  Widget _result(_WriteResult last) {
    final time = last.time.toIso8601String().substring(11, 19);
    if (last.error != null) return SelectableText(last.error!, style: const TextStyle(color: Colors.red));
    return widget.withoutResponse
        ? SelectableText('Sent $time · ${last.value} (no acknowledgement)')
        : SelectableText('✓ Acknowledged $time · ${last.value}', style: const TextStyle(color: Colors.green));
  }
}
