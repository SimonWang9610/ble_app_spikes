import 'package:ble_poc_dart/ble_poc_dart.dart';
import 'package:flutter/material.dart';

/// One thing the user can do with a characteristic; each gets its own row and dialog.
enum Operation {
  read('read', Color(0xFF007AFF)),
  write('write', Color(0xFFAF52DE)),
  writeWithoutResponse('write without response', Color(0xFF5856D6)),
  notify('notify', Color(0xFF34C759)),
  indicate('indicate', Color(0xFF30B0C7));

  const Operation(this.label, this.color);

  final String label;
  final Color color;

  bool get isSubscription => this == notify || this == indicate;

  /// In display order: read, write, write without response, notify, indicate.
  static List<Operation> of(CharacteristicProperties p) => [
    if (p.read) read,
    if (p.write) write,
    if (p.writeWithoutResponse) writeWithoutResponse,
    if (p.notify) notify,
    if (p.indicate) indicate,
  ];
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
