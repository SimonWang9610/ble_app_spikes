import 'dart:typed_data';

import 'package:ble_poc_dart/ble_poc_dart.dart';
import 'package:equatable/equatable.dart';

import '../ble/ble_service.dart';
import '../bytes.dart';
import '../fixture.dart';

sealed class ConnectionStatus extends Equatable {
  const ConnectionStatus();

  String get text;

  @override
  List<Object?> get props => [text];
}

class Connecting extends ConnectionStatus {
  const Connecting();

  @override
  String get text => 'Connecting…';
}

class Connected extends ConnectionStatus {
  const Connected();

  @override
  String get text => 'Connected';
}

class Reconnecting extends ConnectionStatus {
  const Reconnecting(this.attempt);

  final int attempt;

  @override
  String get text => 'Link lost, reconnecting (attempt $attempt)…';
}

class Disconnecting extends ConnectionStatus {
  const Disconnecting();

  @override
  String get text => 'Disconnecting…';
}

class Disconnected extends ConnectionStatus {
  const Disconnected([this.reason]);

  final String? reason;

  @override
  String get text => reason == null ? 'Disconnected' : 'Disconnected: $reason';
}

enum ValueSource { read, received, written }

const _keep = Object();

/// One characteristic as the user sees it.
class CharState extends Equatable {
  const CharState({
    required this.ref,
    required this.properties,
    this.latest,
    this.latestTime,
    this.source,
    this.subscribed = false,
    this.receivedCount = 0,
    this.busy,
    this.error,
  });

  final CharacteristicRef ref;
  final CharacteristicProperties properties;
  final Uint8List? latest;
  final DateTime? latestTime;
  final ValueSource? source;

  /// What the user asked for; re-applied after a reconnect.
  final bool subscribed;
  final int receivedCount;
  final String? busy;
  final String? error;

  String get key => keyOf(ref.service, ref.characteristic);
  String get name => Fixture.shortName(ref.characteristic);
  bool get canSubscribe => properties.notify || properties.indicate;
  bool get canWrite => properties.write || properties.writeWithoutResponse;

  String show(List<int> value) => display(value, asCounter: canSubscribe);

  static String keyOf(String service, String characteristic) => '$service/$characteristic';

  /// `busy` and `error` take null to clear, so they use a sentinel for "unchanged".
  CharState copyWith({
    Uint8List? latest,
    DateTime? latestTime,
    ValueSource? source,
    bool? subscribed,
    int? receivedCount,
    Object? busy = _keep,
    Object? error = _keep,
  }) => CharState(
    ref: ref,
    properties: properties,
    latest: latest ?? this.latest,
    latestTime: latestTime ?? this.latestTime,
    source: source ?? this.source,
    subscribed: subscribed ?? this.subscribed,
    receivedCount: receivedCount ?? this.receivedCount,
    busy: busy == _keep ? this.busy : busy as String?,
    error: error == _keep ? this.error : error as String?,
  );

  @override
  List<Object?> get props => [ref.remoteId, key, latest, latestTime, source, subscribed, receivedCount, busy, error];
}

class ServiceGroup extends Equatable {
  const ServiceGroup(this.uuid, this.keys);

  final String uuid;
  final List<String> keys;

  @override
  List<Object?> get props => [uuid, keys];
}

/// The connected device, or none (`remoteId == null`). Outlives the Device screen.
class SessionState extends Equatable {
  const SessionState({
    this.remoteId,
    this.name = '',
    this.status = const Disconnected(),
    this.autoReconnect = true,
    this.rssi,
    this.mtu,
    this.services = const [],
    this.chars = const {},
  });

  final String? remoteId;
  final String name;
  final ConnectionStatus status;
  final bool autoReconnect;
  final int? rssi;
  final int? mtu;
  final List<ServiceGroup> services;
  final Map<String, CharState> chars;

  bool get isConnected => status is Connected;

  SessionState copyWith({
    ConnectionStatus? status,
    bool? autoReconnect,
    int? rssi,
    int? mtu,
    List<ServiceGroup>? services,
    Map<String, CharState>? chars,
  }) => SessionState(
    remoteId: remoteId,
    name: name,
    status: status ?? this.status,
    autoReconnect: autoReconnect ?? this.autoReconnect,
    rssi: rssi ?? this.rssi,
    mtu: mtu ?? this.mtu,
    services: services ?? this.services,
    chars: chars ?? this.chars,
  );

  @override
  List<Object?> get props => [remoteId, name, status, autoReconnect, rssi, mtu, services, chars];
}
