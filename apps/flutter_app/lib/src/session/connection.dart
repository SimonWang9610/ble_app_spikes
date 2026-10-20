import 'dart:async';

import 'package:ble_poc_dart/ble_poc_dart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../ble/ble_service.dart';
import '../log/log.dart';
import 'current_device.dart';

part 'connection.g.dart';

sealed class ConnectionStatus {
  const ConnectionStatus(this.text);

  final String text;
}

class Connecting extends ConnectionStatus {
  const Connecting() : super('Connecting…');
}

class Connected extends ConnectionStatus {
  const Connected() : super('Connected');
}

class Reconnecting extends ConnectionStatus {
  const Reconnecting(this.attempt) : super('Link lost, reconnecting (attempt $attempt)…');

  final int attempt;
}

class Disconnecting extends ConnectionStatus {
  const Disconnecting() : super('Disconnecting…');
}

class Disconnected extends ConnectionStatus {
  const Disconnected([this.reason]) : super(reason == null ? 'Disconnected' : 'Disconnected: $reason');

  final String? reason;
}

/// The current device and its link, or none (`remoteId == null`). Outlives the Device screen.
class ConnectionInfo {
  const ConnectionInfo({
    this.remoteId,
    this.name = '',
    this.status = const Disconnected(),
    this.autoReconnect = true,
    this.rssi,
    this.mtu,
  });

  final String? remoteId;
  final String name;
  final ConnectionStatus status;
  final bool autoReconnect;
  final int? rssi;
  final int? mtu;

  bool get isConnected => status is Connected;

  ConnectionInfo copyWith({ConnectionStatus? status, bool? autoReconnect, int? rssi, int? mtu}) => ConnectionInfo(
    remoteId: remoteId,
    name: name,
    status: status ?? this.status,
    autoReconnect: autoReconnect ?? this.autoReconnect,
    rssi: rssi ?? this.rssi,
    mtu: mtu ?? this.mtu,
  );
}

/// The link to the current device: status, RSSI, MTU, uptime, and a watcher per link that reports its loss.
@Riverpod(keepAlive: true)
class Connection extends _$Connection {
  static const _timeout = Duration(seconds: 10);

  StreamSubscription<BluetoothConnectionState>? _watcher;
  final _uptime = Stopwatch();

  DeviceLink get _link => ref.read(deviceLinkProvider);
  String get _id => state.remoteId ?? (throw StateError('no device'));

  @override
  ConnectionInfo build() {
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
    }
  }

  void setAutoReconnect(bool on) => state = state.copyWith(autoReconnect: on);

  void refreshMtu() => state = state.copyWith(mtu: tryOrNull(() => _link.mtu(_id)));

  Future<void> refreshRssi() async {
    final id = _id;
    try {
      final rssi = await Log.api('readRssi()', () => _link.readRssi(id));
      state = state.copyWith(rssi: rssi);
    } catch (error) {
      Log.error('RSSI failed: ${describeError(error)}');
    }
  }

  Future<void> connect() {
    final id = _id;
    return Log.api('connect(timeout: 10s)', () => _link.connect(id, _timeout));
  }

  /// Watches the new link, replacing the last one's watcher; `onLost` runs when it drops while Connected.
  void watch({required void Function() onLost}) {
    _unwatch();
    _watcher = _link.connectionStates(_id).listen((s) {
      // The stream emits the current state first; only a drop from Connected is a link loss.
      if (s != BluetoothConnectionState.disconnected || state.status is! Connected) return;
      Log.event('Link lost after ${(_uptime.elapsedMilliseconds / 1000).toStringAsFixed(1)} s');
      onLost();
    });
  }

  /// Drops the link or a pending connect, keeping the device; a failed reconnect attempt ends with it.
  Future<void> dropLink() async {
    final id = _id;
    try {
      await Log.api('disconnect()', () => _link.disconnect(id));
    } catch (error) {
      Log.error('Disconnect failed: ${describeError(error)}');
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
