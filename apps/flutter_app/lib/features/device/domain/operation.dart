import 'package:ble_poc_dart/ble_poc_dart.dart';

/// One thing the user can do with a characteristic; each gets its own row and dialog.
enum Operation {
  read('read'),
  write('write'),
  writeWithoutResponse('write without response'),
  notify('notify'),
  indicate('indicate');

  const Operation(this.label);

  final String label;

  bool get isSubscription => this == notify || this == indicate;
  bool get isWrite => this == write || this == writeWithoutResponse;

  /// In display order: read, write, write without response, notify, indicate.
  static List<Operation> of(CharacteristicProperties p) => [
    if (p.read) read,
    if (p.write) write,
    if (p.writeWithoutResponse) writeWithoutResponse,
    if (p.notify) notify,
    if (p.indicate) indicate,
  ];
}
