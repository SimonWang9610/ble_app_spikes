/// Identifies one characteristic of one device.
class CharacteristicRef {
  const CharacteristicRef(this.remoteId, this.service, this.characteristic);

  final String remoteId;
  final String service;
  final String characteristic;
}
