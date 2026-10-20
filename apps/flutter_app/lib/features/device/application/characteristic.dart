import 'dart:typed_data';
import 'package:flutter_app/core/ble/ble_service.dart';
import 'package:flutter_app/core/log/logger.dart';
import 'package:flutter_app/core/utils/errors.dart';
import 'package:flutter_app/features/device/application/current_device.dart';
import 'package:flutter_app/features/device/domain/char_key.dart';
import 'package:flutter_app/features/device/domain/char_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'characteristic.g.dart';

/// One characteristic's latest value, busy / error and subscription flag. Kept while its device is the
/// current one; after that it starts empty and goes once nothing shows it.
@riverpod
class Characteristic extends _$Characteristic {
  late Logger _log;

  @override
  CharState build(CharKey key) {
    _log = ref.watch(loggerProvider);
    if (ref.watch(currentDeviceProvider)?.remoteId == key.ref.remoteId) ref.keepAlive();
    return CharState(key);
  }

  Future<void> read() => track('Reading…', () async {
    final io = ref.read(gattIOProvider);
    final value = await _log.api('read ${key.name}', () => io.read(key.ref));
    _update((c) => c.copyWith(latest: value, latestTime: DateTime.now(), source: ValueSource.read));
    _log.value('${key.name} read ${key.show(value)}');
  });

  /// Completes once the write is done (acknowledged, or sent without response); throws if it failed.
  Future<void> write(Uint8List value, {required bool withoutResponse}) => track('Writing…', () async {
    final io = ref.read(gattIOProvider);
    await _log.api(
      'write ${key.name} withoutResponse: $withoutResponse',
      () => io.write(key.ref, value, withoutResponse: withoutResponse),
    );
    _update((c) => c.copyWith(latest: value, latestTime: DateTime.now(), source: ValueSource.written));
    _log.value('${key.name} wrote ${key.show(value)}');
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
    _log.value('${key.name} received ${key.show(value)}');
  }

  /// Shows `busy` while `body` runs; a failure becomes this characteristic's error and a log line.
  Future<void> track(String busy, Future<void> Function() body, {bool rethrowErrors = false}) async {
    _update((c) => c.copyWith(busy: busy, error: null));
    try {
      await body();
    } catch (error) {
      _update((c) => c.copyWith(error: describeError(error)));
      _log.error('${key.name}: ${describeError(error)}');
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
