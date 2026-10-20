import 'dart:typed_data';

import 'package:ble_poc_dart/ble_poc_dart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../ble/ble_service.dart';
import '../bytes.dart';
import '../fixture.dart';
import '../log/log.dart';
import 'current_device.dart';

part 'characteristic.g.dart';

/// One characteristic of one device and what it supports. Equal across rediscoveries, so its
/// [characteristicProvider] (and the values in it) survives a reconnect.
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

enum ValueSource { read, received, written }

const _keep = Object();

/// One characteristic as the user sees it. The write form is not here: it belongs to the sheet.
class CharState {
  const CharState(
    this.key, {
    this.latest,
    this.latestTime,
    this.source,
    this.subscribed = false,
    this.receivedCount = 0,
    this.busy,
    this.error,
  });

  final CharKey key;
  final Uint8List? latest;
  final DateTime? latestTime;
  final ValueSource? source;

  /// What the user asked for; re-applied after a reconnect.
  final bool subscribed;
  final int receivedCount;
  final String? busy;
  final String? error;

  String show(List<int> value) => key.show(value);

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
    key,
    latest: latest ?? this.latest,
    latestTime: latestTime ?? this.latestTime,
    source: source ?? this.source,
    subscribed: subscribed ?? this.subscribed,
    receivedCount: receivedCount ?? this.receivedCount,
    busy: busy == _keep ? this.busy : busy as String?,
    error: error == _keep ? this.error : error as String?,
  );
}

/// One characteristic's latest value, busy / error and subscription flag. Kept while its device is the
/// current one; after that it starts empty and goes once nothing shows it.
@riverpod
class Characteristic extends _$Characteristic {
  @override
  CharState build(CharKey key) {
    if (ref.watch(currentDeviceProvider)?.remoteId == key.ref.remoteId) ref.keepAlive();
    return CharState(key);
  }

  Future<void> read() => track('Reading…', () async {
    final io = ref.read(gattIOProvider);
    final value = await Log.api('read ${key.name}', () => io.read(key.ref));
    _update((c) => c.copyWith(latest: value, latestTime: DateTime.now(), source: ValueSource.read));
    Log.value('${key.name} read ${key.show(value)}');
  });

  /// Completes once the write is done (acknowledged, or sent without response); throws if it failed.
  Future<void> write(Uint8List value, {required bool withoutResponse}) => track('Writing…', () async {
    final io = ref.read(gattIOProvider);
    await Log.api(
      'write ${key.name} withoutResponse: $withoutResponse',
      () => io.write(key.ref, value, withoutResponse: withoutResponse),
    );
    _update((c) => c.copyWith(latest: value, latestTime: DateTime.now(), source: ValueSource.written));
    Log.value('${key.name} wrote ${key.show(value)}');
  }, rethrowErrors: true);

  void setSubscribed(bool on) => _update((c) => c.copyWith(subscribed: on));

  void received(Uint8List value) {
    _update(
      (c) => c.copyWith(
        latest: value,
        latestTime: DateTime.now(),
        source: ValueSource.received,
        receivedCount: c.receivedCount + 1,
      ),
    );
    Log.value('${key.name} received ${key.show(value)}');
  }

  /// Shows `busy` while `body` runs; a failure becomes this characteristic's error and a log line.
  Future<void> track(String busy, Future<void> Function() body, {bool rethrowErrors = false}) async {
    _update((c) => c.copyWith(busy: busy, error: null));
    try {
      await body();
    } catch (error) {
      _update((c) => c.copyWith(error: describeError(error)));
      Log.error('${key.name}: ${describeError(error)}');
      if (rethrowErrors) rethrow;
    } finally {
      _update((c) => c.copyWith(busy: null));
    }
  }

  // A disposed notifier can't take state; a result arriving after Disconnect is dropped.
  void _update(CharState Function(CharState) change) {
    if (ref.mounted) state = change(state);
  }
}
