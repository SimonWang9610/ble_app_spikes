// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'current_device.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The session's lifetime: every session provider watches it, so each is rebuilt (and frees what it
/// holds in `ref.onDispose`) when the device changes or goes away. Only DeviceSession sets it.

@ProviderFor(CurrentDevice)
final currentDeviceProvider = CurrentDeviceProvider._();

/// The session's lifetime: every session provider watches it, so each is rebuilt (and frees what it
/// holds in `ref.onDispose`) when the device changes or goes away. Only DeviceSession sets it.
final class CurrentDeviceProvider
    extends $NotifierProvider<CurrentDevice, Device?> {
  /// The session's lifetime: every session provider watches it, so each is rebuilt (and frees what it
  /// holds in `ref.onDispose`) when the device changes or goes away. Only DeviceSession sets it.
  CurrentDeviceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentDeviceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentDeviceHash();

  @$internal
  @override
  CurrentDevice create() => CurrentDevice();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Device? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Device?>(value),
    );
  }
}

String _$currentDeviceHash() => r'004a0745f13e8bfc00607aa6a2653cffc1f27ff0';

/// The session's lifetime: every session provider watches it, so each is rebuilt (and frees what it
/// holds in `ref.onDispose`) when the device changes or goes away. Only DeviceSession sets it.

abstract class _$CurrentDevice extends $Notifier<Device?> {
  Device? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<Device?, Device?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Device?, Device?>,
              Device?,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
