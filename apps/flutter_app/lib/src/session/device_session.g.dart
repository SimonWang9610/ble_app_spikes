// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_session.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Orders the parts of the current device's session; holds no state. The parts live as long as
/// `currentDeviceProvider` names the device, so going back to Nearby keeps the connection.

@ProviderFor(DeviceSession)
final deviceSessionProvider = DeviceSessionProvider._();

/// Orders the parts of the current device's session; holds no state. The parts live as long as
/// `currentDeviceProvider` names the device, so going back to Nearby keeps the connection.
final class DeviceSessionProvider
    extends $NotifierProvider<DeviceSession, void> {
  /// Orders the parts of the current device's session; holds no state. The parts live as long as
  /// `currentDeviceProvider` names the device, so going back to Nearby keeps the connection.
  DeviceSessionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deviceSessionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deviceSessionHash();

  @$internal
  @override
  DeviceSession create() => DeviceSession();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$deviceSessionHash() => r'87d405fa3dc18dda3868a57e36ce4adbda3470e7';

/// Orders the parts of the current device's session; holds no state. The parts live as long as
/// `currentDeviceProvider` names the device, so going back to Nearby keeps the connection.

abstract class _$DeviceSession extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
