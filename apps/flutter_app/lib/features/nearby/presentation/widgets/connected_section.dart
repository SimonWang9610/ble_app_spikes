import 'package:flutter/material.dart';
import 'package:flutter_app/features/device/application/connection.dart';
import 'package:flutter_app/features/nearby/presentation/widgets/device_tile.dart';
import 'package:flutter_app/features/nearby/presentation/widgets/section_header.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The current device, if any, so the user can go back to it.
class ConnectedSection extends ConsumerWidget {
  const ConnectedSection({super.key, required this.onOpen});

  final void Function(String remoteId, String name) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Rebuilds only when the connected device or its status changes, not on RSSI or MTU.
    final (remoteId, name, status) = ref.watch(connectionProvider.select((c) => (c.remoteId, c.name, c.status)));
    if (remoteId == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Connected'),
        DeviceTile(name: name, detail: status.text, onTap: () => onOpen(remoteId, name)),
      ],
    );
  }
}
