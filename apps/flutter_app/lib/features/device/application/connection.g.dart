// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connection.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The link to the current device: status, RSSI, MTU, uptime, and a watcher per link that reports its loss.

@ProviderFor(Connection)
final connectionProvider = ConnectionProvider._();

/// The link to the current device: status, RSSI, MTU, uptime, and a watcher per link that reports its loss.
final class ConnectionProvider
    extends $NotifierProvider<Connection, ConnectionInfo> {
  /// The link to the current device: status, RSSI, MTU, uptime, and a watcher per link that reports its loss.
  ConnectionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'connectionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$connectionHash();

  @$internal
  @override
  Connection create() => Connection();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ConnectionInfo value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ConnectionInfo>(value),
    );
  }
}

String _$connectionHash() => r'0b1554fc5804127ed6550b7d48c1687c16262d64';

/// The link to the current device: status, RSSI, MTU, uptime, and a watcher per link that reports its loss.

abstract class _$Connection extends $Notifier<ConnectionInfo> {
  ConnectionInfo build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<ConnectionInfo, ConnectionInfo>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ConnectionInfo, ConnectionInfo>,
              ConnectionInfo,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
