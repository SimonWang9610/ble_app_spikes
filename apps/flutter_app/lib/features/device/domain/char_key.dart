import 'package:ble_poc_dart/ble_poc_dart.dart';
import 'package:flutter_app/core/ble/characteristic_ref.dart';
import 'package:flutter_app/core/fixture/fixture.dart';
import 'package:flutter_app/core/utils/bytes.dart';

/// One characteristic of one device and what it supports. Equal across rediscoveries, so its
/// `characteristicProvider` (and the values in it) survives a reconnect.
class CharKey {
  const CharKey(this.ref, this.properties);

  final CharacteristicRef ref;
  final CharacteristicProperties properties;

  String get name => Fixture.shortName(ref.characteristic);
  bool get canSubscribe => properties.notify || properties.indicate;

  /// Writable and notifying, like VALUE: a write comes back as a notification, so it is subscribed at connect.
  bool get echoes => canSubscribe && (properties.write || properties.writeWithoutResponse);

  /// Only notify / indicate characteristics, like NOTIFY, send u32 counters.
  bool get sendsCounters => canSubscribe && !properties.read && !echoes;

  String show(List<int> value) => display(value, asCounter: sendsCounters);

  @override
  bool operator ==(Object other) =>
      other is CharKey &&
      other.ref.remoteId == ref.remoteId &&
      other.ref.service == ref.service &&
      other.ref.characteristic == ref.characteristic;

  @override
  int get hashCode => Object.hash(ref.remoteId, ref.service, ref.characteristic);
}
