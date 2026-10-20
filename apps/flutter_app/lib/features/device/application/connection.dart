import 'dart:async';
import 'package:ble_poc_dart/ble_poc_dart.dart';
import 'package:flutter_app/core/ble/ble_service.dart';
import 'package:flutter_app/core/log/logger.dart';
import 'package:flutter_app/core/utils/errors.dart';
import 'package:flutter_app/features/device/application/current_device.dart';
import 'package:flutter_app/features/device/domain/connection_info.dart';
import 'package:flutter_app/features/device/domain/connection_status.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'connection.g.dart';

/// The link to the current device: status, RSSI, MTU, uptime, and a watcher per link that reports its loss.
@Riverpod(keepAlive: true)
class Connection extends _$Connection {
  static const _timeout = Duration(seconds: 10);

  late Logger _log;
  StreamSubscription<BluetoothConnectionState>? _watcher;
  void Function()? _onLost;
  bool _linkUp = false;
  final _uptime = Stopwatch();

  DeviceLink get _link => ref.read(deviceLinkProvider);
  String get _id => state.remoteId ?? (throw StateError('no device'));

  @override
  ConnectionInfo build() {
    _log = ref.watch(loggerProvider);
    final device = ref.watch(currentDeviceProvider);
    ref.onDispose(_unwatch);
    return ConnectionInfo(remoteId: device?.remoteId, name: device?.name ?? '');
  }

  void setStatus(ConnectionStatus status) {
    state = state.copyWith(status: status);
    if (status is Connected) {
      _uptime
        ..reset()
        ..start();
      // The link dropped while connecting (e.g. during the subscribes); report it now.
      if (_watcher != null && !_linkUp) _lost();
    }
  }

  void setAutoReconnect(bool on) => state = state.copyWith(autoReconnect: on);

  void refreshMtu() => state = state.copyWith(mtu: tryOrNull(() => _link.mtu(_id)));

  Future<void> refreshRssi() async {
    final id = _id;
    try {
      final rssi = await _log.api('readRssi()', () => _link.readRssi(id));
      state = state.copyWith(rssi: rssi);
    } catch (error) {
      _log.error('RSSI failed: ${describeError(error)}');
    }
  }

  Future<void> connect() {
    final id = _id;
    return _log.api('connect(timeout: 10s)', () => _link.connect(id, _timeout));
  }

  /// Watches the new link, replacing the last one's watcher; `onLost` runs when it drops while Connected.
  void watch({required void Function() onLost}) {
    _unwatch();
    _onLost = onLost;
    _linkUp = true;
    _watcher = _link.connectionStates(_id).listen((s) {
      _linkUp = s == BluetoothConnectionState.connected;
      // The stream emits the current state first; only a drop from Connected is a link loss.
      if (s == BluetoothConnectionState.disconnected && state.status is Connected) _lost();
    });
  }

  void _lost() {
    _log.event('Link lost after ${(_uptime.elapsedMilliseconds / 1000).toStringAsFixed(1)} s');
    _onLost?.call();
  }

  /// Drops the link or a pending connect, keeping the device; a failed reconnect attempt ends with it.
  Future<void> dropLink() async {
    final id = _id;
    try {
      await _log.api('disconnect()', () => _link.disconnect(id));
    } catch (error) {
      _log.error('Disconnect failed: ${describeError(error)}');
    }
  }

  /// Drops the link and forgets the device handle; the watcher goes when the device does.
  Future<void> disconnect() async {
    final id = _id;
    final link = _link;
    await dropLink();
    link.forget(id);
  }

  void _unwatch() {
    _watcher?.cancel();
    _watcher = null;
  }
}
