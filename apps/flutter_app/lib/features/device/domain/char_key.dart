import 'package:ble_poc_dart/ble_poc_dart.dart';
import 'package:flutter_app/core/ble/ble_service.dart';
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

  String show(List<int> value) => display(value, asCounter: canSubscribe);

  @override
  bool operator ==(Object other) =>
      other is CharKey &&
      other.ref.remoteId == ref.remoteId &&
      other.ref.service == ref.service &&
      other.ref.characteristic == ref.characteristic;

  @override
  int get hashCode => Object.hash(ref.remoteId, ref.service, ref.characteristic);
}
