import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_app/core/ble/ble_service.dart';
import 'package:flutter_app/core/log/logger.dart';
import 'package:flutter_app/core/utils/errors.dart';
import 'package:flutter_app/features/device/application/characteristic.dart';
import 'package:flutter_app/features/device/application/current_device.dart';
import 'package:flutter_app/features/device/domain/char_key.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'subscriptions.g.dart';

/// Notify / indicate value streams of the current device, and which characteristics the user wants them for.
/// No UI state: a characteristic shows its own `subscribed` flag and values.
@Riverpod(keepAlive: true)
class Subscriptions extends _$Subscriptions {
  final _streams = <CharKey, StreamSubscription<Uint8List>>{};
  final _wanted = <CharKey>{};
  late Logger _log;

  // The notifier outlives a device change, so each build starts empty and frees the last device's streams.
  @override
  void build() {
    _log = ref.watch(loggerProvider);
    ref.watch(currentDeviceProvider);
    ref.onDispose(_cancelStreams);
    _wanted.clear();
  }

  GattIO get _io => ref.read(gattIOProvider);
  Characteristic _char(CharKey key) => ref.read(characteristicProvider(key).notifier);

  /// What the user subscribed to, re-applied by [resume].
  List<CharKey> get wanted => List.of(_wanted);

  Future<void> set(CharKey key, bool on) {
    final char = _char(key);
    final io = _io;
    return char.track(on ? 'Subscribing…' : 'Unsubscribing…', () async {
      if (on) {
        await _enable(key);
        _wanted.add(key);
        char.setSubscribed(true);
        _log.event('${key.name} subscribed');
      } else {
        _wanted.remove(key);
        await _streams.remove(key)?.cancel();
        char.setSubscribed(false);
        await _log.api('setNotifyValue(false) ${key.name}', () => io.setNotify(key.ref, false));
        _log.event('${key.name} unsubscribed');
      }
    });
  }

  /// Subscribes, with no busy state, to every one of `keys` that echoes writes; a failure is only logged.
  /// Stops quietly once `ended` says the session is over.
  Future<void> autoSubscribe(Iterable<CharKey> keys, {required bool Function() ended}) async {
    for (final key in keys.where((k) => k.echoes && !_wanted.contains(k))) {
      try {
        await _enable(key);
        if (ended()) return _streams.remove(key)?.cancel();
        _wanted.add(key);
        _char(key).setSubscribed(true);
        _log.event('${key.name} subscribed');
      } catch (error) {
        if (ended()) return;
        _log.error('${key.name}: subscribe failed: ${describeError(error)}');
      }
    }
  }

  /// Re-applies every wanted subscription on a new link.
  Future<void> resume() async {
    for (final key in wanted) {
      await _enable(key);
    }
  }

  /// Turns notify off for every wanted one; only works over a live link. Failures are logged.
  Future<void> unsubscribeAll() async {
    final io = _io;
    for (final key in wanted) {
      try {
        await _log.api('setNotifyValue(false) ${key.name}', () => io.setNotify(key.ref, false));
      } catch (error) {
        _log.error('${key.name}: ${describeError(error)}');
      }
    }
  }

  /// The link is gone: stop the value streams but keep the wanted ones for [resume].
  void pause() => _cancelStreams();

  /// The link is gone for good: also forget what the user wanted.
  void drop() {
    _cancelStreams();
    for (final key in wanted) {
      _char(key).setSubscribed(false);
    }
    _wanted.clear();
  }

  void _cancelStreams() {
    for (final stream in _streams.values) {
      stream.cancel();
    }
    _streams.clear();
  }

  /// Listens first, then enables notify / indicate, so no value is missed. The stream stays in the map,
  /// so pause, drop or the next device's rebuild cancels it.
  Future<void> _enable(CharKey key) async {
    final io = _io;
    await _streams.remove(key)?.cancel();
    final stream = io.values(key.ref).listen((value) => _char(key).received(value));
    _streams[key] = stream;
    try {
      await _log.api('setNotifyValue(true) ${key.name}', () => io.setNotify(key.ref, true));
    } catch (_) {
      if (_streams[key] == stream) _streams.remove(key);
      await stream.cancel();
      rethrow;
    }
  }
}
