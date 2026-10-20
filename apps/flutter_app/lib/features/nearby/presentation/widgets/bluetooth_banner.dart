import 'package:ble_poc_dart/ble_poc_dart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/core/ble/adapter.dart';
import 'package:flutter_app/core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shown while Bluetooth is off, not ready or failed to start.
class BluetoothBanner extends ConsumerWidget {
  const BluetoothBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adapter = ref.watch(adapterProvider);
    final String? text;
    if (adapter.error != null) {
      text = 'Bluetooth unavailable: ${adapter.error}';
    } else if (adapter.bluetooth != null && adapter.bluetooth != BluetoothAdapterState.poweredOn) {
      text = adapter.bluetooth == BluetoothAdapterState.poweredOff ? 'Bluetooth is off' : 'Bluetooth is not ready';
    } else {
      text = null;
    }
    if (text == null) return const SizedBox.shrink();
    final warning = context.appColors.warning;
    return ListTile(
      leading: Icon(Icons.warning_amber, color: warning),
      title: Text(text, style: TextStyle(color: warning)),
    );
  }
}
