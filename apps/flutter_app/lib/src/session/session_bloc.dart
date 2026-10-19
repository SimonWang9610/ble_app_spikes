import 'dart:async';
import 'dart:typed_data';

import 'package:ble_poc_dart/ble_poc_dart.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../ble/ble_service.dart';
import '../log/device_log.dart';
import 'session_state.dart';

sealed class SessionEvent {
  const SessionEvent();
}

/// The user picked a device: connect to it (disconnecting another one first).
class SessionOpened extends SessionEvent {
  const SessionOpened(this.remoteId, this.name);

  final String remoteId;
  final String name;
}

class SessionConnectRequested extends SessionEvent {
  const SessionConnectRequested();
}

class SessionDisconnectRequested extends SessionEvent {
  const SessionDisconnectRequested();
}

class AutoReconnectToggled extends SessionEvent {
  const AutoReconnectToggled(this.on);

  final bool on;
}

class RssiRequested extends SessionEvent {
  const RssiRequested();
}

class ReadRequested extends SessionEvent {
  const ReadRequested(this.key);

  final String key;
}

class WriteRequested extends SessionEvent {
  const WriteRequested(this.key, this.value, {required this.withoutResponse});

  final String key;
  final Uint8List value;
  final bool withoutResponse;
}

class SubscribeRequested extends SessionEvent {
  const SubscribeRequested(this.key, {required this.on});

  final String key;
  final bool on;
}

class _LinkChanged extends SessionEvent {
  const _LinkChanged(this.state);

  final BluetoothConnectionState state;
}

class _ValueReceived extends SessionEvent {
  const _ValueReceived(this.key, this.value);

  final String key;
  final Uint8List value;
}

/// One connected device: connection, auto-reconnect and subscriptions. App-wide, so going back to
/// Nearby keeps everything until Disconnect.
///
/// A Bloc, because it is a state machine driven by events from the user (connect, read, ...) and
/// from the device (link changed, value received). Stream subscriptions live here, not in the state.
class SessionBloc extends Bloc<SessionEvent, SessionState> {
  SessionBloc(this._service, this._log) : super(const SessionState()) {
    on<SessionOpened>(_onOpened);
    on<SessionConnectRequested>(_onConnect);
    on<SessionDisconnectRequested>(_onDisconnect);
    on<AutoReconnectToggled>((e, emit) => emit(state.copyWith(autoReconnect: e.on)));
    on<RssiRequested>(_onRssi);
    on<ReadRequested>(_onRead);
    on<WriteRequested>(_onWrite);
    on<SubscribeRequested>(_onSubscribe);
    on<_LinkChanged>(_onLinkChanged);
    on<_ValueReceived>(_onValueReceived);
  }

  static const _reconnectDelays = [1, 2, 4, 8, 10];
  static const _reconnectLimit = Duration(seconds: 60);

  final BleService _service;
  final DeviceLog _log;
  StreamSubscription<BluetoothConnectionState>? _watcher;
  final _values = <String, StreamSubscription<Uint8List>>{};
  // Bumped to stop a running reconnect loop.
  int _reconnectRun = 0;

  String get _id => state.remoteId!;

  // Connection

  Future<void> _onOpened(SessionOpened event, Emitter<SessionState> emit) async {
    if (state.remoteId == event.remoteId) {
      if (state.status is Disconnected) add(const SessionConnectRequested());
      return;
    }
    if (state.remoteId != null) await _disconnect(emit);
    emit(SessionState(remoteId: event.remoteId, name: event.name.isEmpty ? event.remoteId : event.name));
    add(const SessionConnectRequested());
  }

  Future<void> _onConnect(SessionConnectRequested event, Emitter<SessionState> emit) async {
    if (state.remoteId == null) return;
    emit(state.copyWith(status: const Connecting()));
    _log.event('Connecting to ${state.name}');
    try {
      await _establish(emit);
      emit(state.copyWith(status: const Connected()));
      _log.event('Connected');
    } catch (error) {
      emit(state.copyWith(status: Disconnected(describeError(error))));
      _log.error('Connect failed: ${describeError(error)}');
    }
  }

  Future<void> _onDisconnect(SessionDisconnectRequested event, Emitter<SessionState> emit) => _disconnect(emit);

  Future<void> _disconnect(Emitter<SessionState> emit) async {
    if (state.remoteId == null) return;
    _reconnectRun++;
    emit(state.copyWith(status: const Disconnecting()));
    await _cancelValues();
    try {
      await _log.api('disconnect()', () => _service.disconnect(_id));
    } catch (error) {
      _log.error('Disconnect failed: ${describeError(error)}');
    }
    await _watcher?.cancel();
    _watcher = null;
    emit(const SessionState());
    _log.event('Disconnected');
  }

  Future<void> _onRssi(RssiRequested event, Emitter<SessionState> emit) async {
    try {
      final rssi = await _log.api('readRssi()', () => _service.readRssi(_id));
      emit(state.copyWith(rssi: rssi));
    } catch (error) {
      _log.error('RSSI failed: ${describeError(error)}');
    }
  }

  /// Connect, discover, then re-apply the user's subscriptions.
  Future<void> _establish(Emitter<SessionState> emit) async {
    await _log.api('connect(timeout: 10s)', () => _service.connect(_id, const Duration(seconds: 10)));
    _watcher ??= _service.connectionStates(_id).listen((s) => add(_LinkChanged(s)));
    final found = await _log.api('discoverServices()', () => _service.discoverServices(_id));

    // Keep existing characteristic states, so values and subscriptions survive rediscovery.
    final chars = <String, CharState>{};
    final groups = <ServiceGroup>[];
    for (final service in found) {
      final keys = <String>[];
      for (final info in service.characteristics) {
        final key = CharState.keyOf(service.serviceUuid, info.characteristicUuid);
        chars[key] =
            state.chars[key] ??
            CharState(
              ref: CharacteristicRef(_id, service.serviceUuid, info.characteristicUuid),
              properties: info.properties,
            );
        keys.add(key);
      }
      groups.add(ServiceGroup(service.serviceUuid, keys));
    }
    emit(state.copyWith(services: groups, chars: chars, mtu: tryOrNull(() => _service.mtu(_id))));
    _log.event('Found ${found.length} services, ${chars.length} characteristics');

    for (final char in chars.values.where((c) => c.subscribed)) {
      await _enableValues(char);
    }
  }

  // Link loss

  Future<void> _onLinkChanged(_LinkChanged event, Emitter<SessionState> emit) async {
    // The stream emits the current state first; only a drop from `connected` is a link loss.
    if (event.state != BluetoothConnectionState.disconnected || state.status is! Connected) return;
    _log.event('Link lost');
    await _cancelValues();
    if (!state.autoReconnect) {
      _clearSubscriptions(emit);
      emit(state.copyWith(status: const Disconnected('link lost')));
      return;
    }
    await _reconnect(emit);
  }

  Future<void> _reconnect(Emitter<SessionState> emit) async {
    final run = ++_reconnectRun;
    final watch = Stopwatch()..start();
    for (var attempt = 1; ; attempt++) {
      if (run != _reconnectRun) return;
      emit(state.copyWith(status: Reconnecting(attempt)));
      _log.event('Reconnecting, attempt $attempt');
      try {
        await _establish(emit);
        if (run != _reconnectRun) return;
        final resumed = state.chars.values.where((c) => c.subscribed).map((c) => c.name).toList()..sort();
        emit(state.copyWith(status: const Connected()));
        _log.event(
          'Reconnected after ${(watch.elapsedMilliseconds / 1000).toStringAsFixed(1)} s'
          '${resumed.isEmpty ? '' : ', resumed ${resumed.join(', ')}'}',
        );
        return;
      } catch (error) {
        _log.error('Reconnect attempt $attempt failed: ${describeError(error)}');
      }
      final delay = Duration(seconds: _reconnectDelays[(attempt - 1).clamp(0, _reconnectDelays.length - 1)]);
      if (watch.elapsed + delay > _reconnectLimit) {
        _clearSubscriptions(emit);
        emit(state.copyWith(status: Disconnected('gave up reconnecting after ${_reconnectLimit.inSeconds} s')));
        _log.error('Gave up reconnecting');
        return;
      }
      await Future<void>.delayed(delay);
    }
  }

  void _clearSubscriptions(Emitter<SessionState> emit) {
    emit(state.copyWith(chars: {for (final e in state.chars.entries) e.key: e.value.copyWith(subscribed: false)}));
  }

  // Characteristic actions

  Future<void> _onRead(ReadRequested event, Emitter<SessionState> emit) => _perform(event.key, 'Reading…', emit, (
    c,
  ) async {
    final value = await _log.api('read ${c.name}', () => _service.read(c.ref));
    _update(emit, event.key, (c) => c.copyWith(latest: value, latestTime: DateTime.now(), source: ValueSource.read));
    _log.value('${c.name} read ${c.show(value)}');
  });

  Future<void> _onWrite(WriteRequested event, Emitter<SessionState> emit) =>
      _perform(event.key, 'Writing…', emit, (c) async {
        await _log.api(
          'write ${c.name} withoutResponse: ${event.withoutResponse}',
          () => _service.write(c.ref, event.value, withoutResponse: event.withoutResponse),
        );
        _update(
          emit,
          event.key,
          (c) => c.copyWith(latest: event.value, latestTime: DateTime.now(), source: ValueSource.written),
        );
        _log.value('${c.name} wrote ${c.show(event.value)}');
      });

  Future<void> _onSubscribe(SubscribeRequested event, Emitter<SessionState> emit) =>
      _perform(event.key, event.on ? 'Subscribing…' : 'Unsubscribing…', emit, (c) async {
        if (event.on) {
          await _enableValues(c);
          _update(emit, event.key, (c) => c.copyWith(subscribed: true));
          _log.event('${c.name} subscribed');
        } else {
          await _values.remove(event.key)?.cancel();
          _update(emit, event.key, (c) => c.copyWith(subscribed: false));
          await _log.api('setNotifyValue(false) ${c.name}', () => _service.setNotify(c.ref, false));
          _log.event('${c.name} unsubscribed');
        }
      });

  void _onValueReceived(_ValueReceived event, Emitter<SessionState> emit) {
    final c = state.chars[event.key];
    if (c == null) return;
    _update(
      emit,
      event.key,
      (c) => c.copyWith(
        latest: event.value,
        latestTime: DateTime.now(),
        source: ValueSource.received,
        receivedCount: c.receivedCount + 1,
      ),
    );
    _log.value('${c.name} received ${c.show(event.value)}');
  }

  /// Listens first, then enables notify / indicate, so no value is missed.
  Future<void> _enableValues(CharState c) async {
    await _values.remove(c.key)?.cancel();
    _values[c.key] = _service.values(c.ref).listen((value) => add(_ValueReceived(c.key, value)));
    try {
      await _log.api('setNotifyValue(true) ${c.name}', () => _service.setNotify(c.ref, true));
    } catch (_) {
      await _values.remove(c.key)?.cancel();
      rethrow;
    }
  }

  Future<void> _cancelValues() async {
    for (final subscription in _values.values) {
      await subscription.cancel();
    }
    _values.clear();
  }

  Future<void> _perform(
    String key,
    String busy,
    Emitter<SessionState> emit,
    Future<void> Function(CharState c) body,
  ) async {
    final c = state.chars[key];
    if (c == null) return;
    _update(emit, key, (c) => c.copyWith(busy: busy, error: null));
    try {
      await body(c);
    } catch (error) {
      _update(emit, key, (c) => c.copyWith(error: describeError(error)));
      _log.error('${c.name}: ${describeError(error)}');
    }
    _update(emit, key, (c) => c.copyWith(busy: null));
  }

  void _update(Emitter<SessionState> emit, String key, CharState Function(CharState) change) {
    final c = state.chars[key];
    if (c == null) return;
    emit(state.copyWith(chars: {...state.chars, key: change(c)}));
  }

  @override
  Future<void> close() async {
    await _cancelValues();
    await _watcher?.cancel();
    return super.close();
  }
}
