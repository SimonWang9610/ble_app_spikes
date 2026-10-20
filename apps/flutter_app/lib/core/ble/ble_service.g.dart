// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ble_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(_bleService)
final _bleServiceProvider = _BleServiceProvider._();

final class _BleServiceProvider
    extends $FunctionalProvider<BleService, BleService, BleService>
    with $Provider<BleService> {
  _BleServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'_bleServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$_bleServiceHash();

  @$internal
  @override
  $ProviderElement<BleService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BleService create(Ref ref) {
    return _bleService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BleService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BleService>(value),
    );
  }
}

String _$_bleServiceHash() => r'aee06042236182378cf2d3466f2a9c36975a6150';

@ProviderFor(bleAdapter)
final bleAdapterProvider = BleAdapterProvider._();

final class BleAdapterProvider
    extends $FunctionalProvider<BleAdapter, BleAdapter, BleAdapter>
    with $Provider<BleAdapter> {
  BleAdapterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bleAdapterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bleAdapterHash();

  @$internal
  @override
  $ProviderElement<BleAdapter> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BleAdapter create(Ref ref) {
    return bleAdapter(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BleAdapter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BleAdapter>(value),
    );
  }
}

String _$bleAdapterHash() => r'519e262232abfd4db406d6595a1e02a1228ec08f';

@ProviderFor(deviceLink)
final deviceLinkProvider = DeviceLinkProvider._();

final class DeviceLinkProvider
    extends $FunctionalProvider<DeviceLink, DeviceLink, DeviceLink>
    with $Provider<DeviceLink> {
  DeviceLinkProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deviceLinkProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deviceLinkHash();

  @$internal
  @override
  $ProviderElement<DeviceLink> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DeviceLink create(Ref ref) {
    return deviceLink(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DeviceLink value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DeviceLink>(value),
    );
  }
}

String _$deviceLinkHash() => r'dd80eae9283b5b68371b6d3bc59f5b9e21f9bdea';

@ProviderFor(gattIO)
final gattIOProvider = GattIOProvider._();

final class GattIOProvider extends $FunctionalProvider<GattIO, GattIO, GattIO>
    with $Provider<GattIO> {
  GattIOProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'gattIOProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$gattIOHash();

  @$internal
  @override
  $ProviderElement<GattIO> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GattIO create(Ref ref) {
    return gattIO(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GattIO value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GattIO>(value),
    );
  }
}

String _$gattIOHash() => r'f6d96329b7b6c60c83f3fe7d577478014f68b2c1';
