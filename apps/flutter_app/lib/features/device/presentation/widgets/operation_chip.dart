import 'package:flutter/material.dart';
import 'package:flutter_app/features/device/domain/operation.dart';

/// The same colours as the Swift app's operation pills.
extension OperationColor on Operation {
  Color get color => switch (this) {
    Operation.read => const Color(0xFF007AFF),
    Operation.write => const Color(0xFFAF52DE),
    Operation.writeWithoutResponse => const Color(0xFF5856D6),
    Operation.notify => const Color(0xFF34C759),
    Operation.indicate => const Color(0xFF30B0C7),
  };
}

/// The operation's label as a pill: colored text on a light tint of the same color.
class OperationChip extends StatelessWidget {
  const OperationChip(this.operation, {super.key});

  final Operation operation;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: operation.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        operation.label,
        style: TextStyle(color: operation.color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
