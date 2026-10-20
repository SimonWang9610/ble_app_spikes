import 'package:flutter/material.dart';
import 'package:flutter_app/core/fixture/fixture.dart';
import 'package:flutter_app/core/theme/app_colors.dart';
import 'package:flutter_app/core/theme/text_styles.dart';
import 'package:flutter_app/features/device/application/characteristic.dart';
import 'package:flutter_app/features/device/domain/char_key.dart';
import 'package:flutter_app/features/device/domain/operation.dart';
import 'package:flutter_app/features/device/presentation/operation_sheet.dart';
import 'package:flutter_app/features/device/presentation/widgets/operation_chip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One (characteristic, operation) row; watches only its characteristic, so it rebuilds alone.
class OperationRow extends ConsumerWidget {
  const OperationRow({super.key, required this.charKey, required this.operation});

  final CharKey charKey;
  final Operation operation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(characteristicProvider(charKey));
    final colors = context.appColors;
    final name = Fixture.nameOf(charKey.ref.characteristic);
    return ListTile(
      title: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (name != null) Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
          OperationChip(operation),
        ],
      ),
      subtitle: Text(
        charKey.ref.characteristic,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.mono.copyWith(fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (operation.isSubscription)
            c.subscribed
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sensors, size: 18, color: colors.success),
                      Text(' ${c.receivedCount}', style: TextStyle(color: colors.success)),
                    ],
                  )
                : Icon(Icons.sensors_off, size: 18, color: colors.muted),
          if (c.error != null) Icon(Icons.error_outline, color: colors.danger),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () => showOperationSheet(context, charKey, operation),
    );
  }
}
