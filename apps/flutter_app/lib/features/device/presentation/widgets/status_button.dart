import 'package:flutter/material.dart';
import 'package:flutter_app/core/theme/app_colors.dart';
import 'package:flutter_app/core/widgets/small_spinner.dart';
import 'package:flutter_app/features/device/application/device_session.dart';
import 'package:flutter_app/features/device/domain/connection_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Disconnect, Connect or a spinner, depending on the link.
class StatusButton extends ConsumerWidget {
  const StatusButton({super.key, required this.status});

  final ConnectionStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.read(deviceSessionProvider.notifier);
    return switch (status) {
      Connected() || Reconnecting() => TextButton(
        onPressed: () {
          session.disconnect();
          Navigator.of(context).pop();
        },
        child: Text('Disconnect', style: TextStyle(color: context.appColors.danger)),
      ),
      Disconnected() => TextButton(onPressed: session.connect, child: const Text('Connect')),
      Connecting() || Disconnecting() => const SmallSpinner(size: 20),
    };
  }
}

extension ConnectionStatusColor on ConnectionStatus {
  Color color(AppColors colors) => switch (this) {
    Connected() => colors.success,
    Connecting() || Reconnecting() || Disconnecting() => colors.warning,
    Disconnected() => colors.danger,
  };
}
