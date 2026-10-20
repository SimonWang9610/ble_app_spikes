import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_app/core/theme/app_colors.dart';
import 'package:flutter_app/core/theme/text_styles.dart';
import 'package:flutter_app/core/utils/bytes.dart';
import 'package:flutter_app/core/utils/errors.dart';
import 'package:flutter_app/core/utils/time_format.dart';
import 'package:flutter_app/features/device/application/characteristic.dart';
import 'package:flutter_app/features/device/domain/char_key.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The result of the last write made from this form.
typedef _WriteResult = ({DateTime time, String value, String? error});

/// A notification received after that write.
typedef _Echo = ({DateTime time, String value});

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
  final _input = TextEditingController();
  ValueFormat _format = ValueFormat.hex;
  String? _inputError;
  _WriteResult? _last;
  _Echo? _echo;

  /// The received count when the last write with response began; the next value received after it is its echo.
  int? _echoAfter;

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
    setState(() {
      _inputError = null;
      _echo = null;
      // A write without response gets no echo shown, even if the device sends one.
      _echoAfter = widget.withoutResponse ? null : ref.read(characteristicProvider(key)).receivedCount;
    });
    String? error;
    try {
      await ref.read(characteristicProvider(key).notifier).write(value, withoutResponse: widget.withoutResponse);
    } catch (e) {
      error = describeError(e);
      _echoAfter = null;
    }
    if (mounted) setState(() => _last = (time: DateTime.now(), value: key.show(value), error: error));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(characteristicProvider(widget.charKey), (_, c) {
      if (_echoAfter case final after? when c.receivedCount > after) {
        setState(() {
          _echo = (time: c.latestTime!, value: c.show(c.latest!));
          _echoAfter = null;
        });
      }
    });
    final subscribed = ref.watch(characteristicProvider(widget.charKey).select((c) => c.subscribed));
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
                style: AppTextStyles.mono,
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
        if (_echo case final echo?)
          SelectableText('Echo ${formatTime(echo.time)} · ${echo.value}')
        else if (_last != null && _last!.error == null && _echoAfter != null && subscribed)
          Text('Waiting for echo…', style: TextStyle(color: context.appColors.muted)),
      ],
    );
  }

  Widget _result(_WriteResult last) {
    final colors = context.appColors;
    final time = formatTime(last.time);
    if (last.error != null) return SelectableText(last.error!, style: TextStyle(color: colors.danger));
    return widget.withoutResponse
        ? SelectableText('Sent $time · ${last.value} (no acknowledgement)')
        : SelectableText('✓ Acknowledged $time · ${last.value}', style: TextStyle(color: colors.success));
  }
}
