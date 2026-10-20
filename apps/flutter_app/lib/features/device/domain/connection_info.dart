import 'package:flutter_app/features/device/domain/connection_status.dart';

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
