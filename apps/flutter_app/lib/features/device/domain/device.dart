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
