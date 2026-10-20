import 'package:flutter_app/features/device/domain/char_key.dart';

/// One service tile: its UUID and its characteristics in discovery order.
class ServiceGroup {
  const ServiceGroup(this.uuid, this.chars);

  final String uuid;
  final List<CharKey> chars;
}
