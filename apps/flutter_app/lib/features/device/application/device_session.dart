import 'package:flutter_app/core/log/logger.dart';
import 'package:flutter_app/core/utils/errors.dart';
import 'package:flutter_app/features/device/application/connection.dart';
import 'package:flutter_app/features/device/application/current_device.dart';
import 'package:flutter_app/features/device/application/gatt.dart';
import 'package:flutter_app/features/device/application/reconnector.dart';
import 'package:flutter_app/features/device/application/subscriptions.dart';
import 'package:flutter_app/features/device/domain/connection_info.dart';
import 'package:flutter_app/features/device/domain/connection_status.dart';
import 'package:flutter_app/features/device/domain/device.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'device_session.g.dart';

/// Orders the parts of the current device's session; holds no state. The parts live as long as
/// `currentDeviceProvider` names the device, so going back to Nearby keeps the connection.
@Riverpod(keepAlive: true)
class DeviceSession extends _$DeviceSession {
  Future<void>? _disconnecting;
  late Logger _log;

  @override
  void build() {
    _log = ref.watch(loggerProvider);
  }

  Device? get _device => ref.read(currentDeviceProvider);
  ConnectionInfo get _info => ref.read(connectionProvider);
  Connection get _connection => ref.read(connectionProvider.notifier);
  Gatt get _gatt => ref.read(gattProvider.notifier);
  Subscriptions get _subscriptions => ref.read(subscriptionsProvider.notifier);
  Reconnector get _reconnector => ref.read(reconnectorProvider.notifier);

  /// Disconnect has begun, or the device changed, since work for `device` started. `identical`, so
  /// picking the same device again still counts as a new session.
  bool _ended(Device device) => !identical(_device, device) || _info.status is Disconnecting;

  /// The user picked a device: connect to it, disconnecting another one first.
  Future<void> open(String remoteId, String name) async {
    final device = _device;
    if (device?.remoteId == remoteId) {
      if (_info.status is Disconnected) await connect();
      return;
    }
    if (device != null) await disconnect();
    ref.read(currentDeviceProvider.notifier).select(remoteId, name);
    await connect();
  }

  Future<void> connect() async {
    final device = _device;
    if (device == null) return;
    final connection = _connection;
    connection.setStatus(const Connecting());
    _log.event('Connecting to ${_info.name}');
    try {
      if (!await establish()) return;
      connection.setStatus(const Connected());
      _log.event('Connected');
    } catch (error) {
      if (_ended(device)) return;
      connection.setStatus(Disconnected(describeError(error)));
      _log.error('Connect failed: ${describeError(error)}');
    }
  }

  /// Connect, discover, then watch the new link, show the services and resume the user's subscriptions;
  /// false if the session ended meanwhile. As a reconnect `attempt`, a failure first drops the half-open
  /// link, so the next attempt starts clean.
  Future<bool> establish({int? attempt}) async {
    final device = _device!;
    final connection = _connection;
    final gatt = _gatt;
    final subscriptions = _subscriptions;
    if (attempt != null) {
      connection.setStatus(Reconnecting(attempt));
      _log.event('Reconnecting, attempt $attempt');
    }
    try {
      await connection.connect();
      final services = await gatt.discover(device.remoteId);
      if (_ended(device)) return false;
      connection.watch(onLost: _linkLost);
      gatt.apply(device.remoteId, services, subscribed: subscriptions.wanted);
      connection.refreshMtu();
      await subscriptions.resume();
      return true;
    } catch (error) {
      if (attempt == null) rethrow;
      _log.error('Reconnect attempt $attempt failed: ${describeError(error)}');
      subscriptions.pause();
      await connection.dropLink();
      rethrow;
    }
  }

  /// A second Disconnect while one runs waits for it.
  Future<void> disconnect() => _disconnecting ??= _disconnect().whenComplete(() => _disconnecting = null);

  /// Unsubscribes over a live link, disconnects, then lets the device go; each part frees the rest itself.
  Future<void> _disconnect() async {
    if (_device == null) return;
    // Rebuilding the reconnector now stops its retry loop; work in flight then sees Disconnecting.
    ref.invalidate(reconnectorProvider);
    ref.read(reconnectorProvider);
    final live = _info.isConnected;
    final connection = _connection;
    connection.setStatus(const Disconnecting());
    if (live) await _subscriptions.unsubscribeAll();
    await connection.disconnect();
    ref.read(currentDeviceProvider.notifier).clear();
    _log.event('Disconnected');
  }

  /// Runs while the link was Connected, so Disconnect hasn't begun.
  Future<void> _linkLost() async {
    final device = _device!;
    _subscriptions.pause();
    if (!_info.autoReconnect) return _end('link lost');
    final took = await _reconnector.start((attempt) => establish(attempt: attempt));
    if (_ended(device)) return;
    if (took == null) {
      _end('gave up reconnecting after ${Reconnector.limit.inSeconds} s');
      _log.error('Gave up reconnecting');
      return;
    }
    final resumed = _subscriptions.wanted.map((k) => k.name).toList()..sort();
    _connection.setStatus(const Connected());
    _log.event(
      'Reconnected after ${(took.inMilliseconds / 1000).toStringAsFixed(1)} s'
      '${resumed.isEmpty ? '' : ', resumed ${resumed.join(', ')}'}',
    );
  }

  /// The link is gone for good but the device stays current, so Connect can start over.
  void _end(String reason) {
    _subscriptions.drop();
    _connection.setStatus(Disconnected(reason));
  }
}
