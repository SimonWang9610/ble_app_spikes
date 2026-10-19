import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../log/device_log.dart';
import '../log/log_cubit.dart';

/// Always-visible device log under every screen; collapsed to the latest line.
class LogPanel extends StatefulWidget {
  const LogPanel({super.key});

  @override
  State<LogPanel> createState() => _LogPanelState();
}

class _LogPanelState extends State<LogPanel> {
  // Pure view state, nobody else needs it, so it stays in the widget.
  bool _expanded = false;
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LogCubit, LogState>(
      builder: (context, log) {
        final entries = log.visible;
        if (_expanded) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
          });
        }
        return Material(
          elevation: 8,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        const Text('Log', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 10),
                        if (_expanded) ...[
                          FilterChip(
                            label: const Text('API calls'),
                            selected: log.showApiCalls,
                            onSelected: context.read<LogCubit>().setShowApiCalls,
                          ),
                          const Spacer(),
                          TextButton(onPressed: context.read<LogCubit>().clear, child: const Text('Clear')),
                        ] else
                          Expanded(
                            child: entries.isEmpty ? const SizedBox.shrink() : _LogLine(entries.last, maxLines: 1),
                          ),
                        Icon(_expanded ? Icons.expand_more : Icons.expand_less),
                      ],
                    ),
                  ),
                ),
                if (_expanded)
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: entries.length,
                      itemBuilder: (context, i) => _LogLine(entries[i]),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LogLine extends StatelessWidget {
  const _LogLine(this.entry, {this.maxLines});

  final LogEntry entry;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final color = switch (entry.kind) {
      LogKind.event => null,
      LogKind.value => Colors.blue,
      LogKind.error => Colors.red,
      LogKind.api => Colors.grey,
    };
    // Plain Text: the panel sits outside the navigator's Overlay, which selectable text needs.
    return Text(
      '${entry.time.toIso8601String().substring(11, 19)}  ${entry.text}',
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
      style: TextStyle(fontFamily: 'Menlo', fontSize: 11, color: color),
    );
  }
}
