import 'package:flutter/material.dart';
import 'package:flutter_app/core/theme/app_colors.dart';
import 'package:flutter_app/features/device/domain/operation.dart';

extension OperationColor on Operation {
  Color color(AppColors colors) => switch (this) {
    Operation.read => colors.read,
    Operation.write => colors.write,
    Operation.writeWithoutResponse => colors.writeWithoutResponse,
    Operation.notify => colors.notify,
    Operation.indicate => colors.indicate,
  };
}

/// The operation's label as a pill: colored text on a light tint of the same color.
class OperationChip extends StatelessWidget {
  const OperationChip(this.operation, {super.key});

  final Operation operation;

  @override
  Widget build(BuildContext context) {
    final color = operation.color(context.appColors);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
      child: Text(
        operation.label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
