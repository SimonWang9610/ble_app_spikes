import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'current_device.g.dart';

/// The device the user picked.
class Device {
  const Device(this.remoteId, this.name);

  final String remoteId;
  final String name;

  @override
  bool operator ==(Object other) => other is Device && other.remoteId == remoteId && other.name == name;

  @override
  int get hashCode => Object.hash(remoteId, name);
}

/// The session's lifetime: every session provider watches it, so each is rebuilt (and frees what it
/// holds in `ref.onDispose`) when the device changes or goes away. Only DeviceSession sets it.
@Riverpod(keepAlive: true)
class CurrentDevice extends _$CurrentDevice {
  @override
  Device? build() => null;

  void select(String remoteId, String name) => state = Device(remoteId, name.isEmpty ? remoteId : name);

  void clear() => state = null;
}
