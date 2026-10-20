// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gatt.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// What the current device offers, as service tiles. The characteristics' own state lives in
/// `characteristicProvider`, keyed so that it survives rediscovery.

@ProviderFor(Gatt)
final gattProvider = GattProvider._();

/// What the current device offers, as service tiles. The characteristics' own state lives in
/// `characteristicProvider`, keyed so that it survives rediscovery.
final class GattProvider extends $NotifierProvider<Gatt, List<ServiceGroup>> {
  /// What the current device offers, as service tiles. The characteristics' own state lives in
  /// `characteristicProvider`, keyed so that it survives rediscovery.
  GattProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'gattProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$gattHash();

  @$internal
  @override
  Gatt create() => Gatt();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<ServiceGroup> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<ServiceGroup>>(value),
    );
  }
}

String _$gattHash() => r'0a1237fad20fe4c23212f79cab27f9457981e321';

/// What the current device offers, as service tiles. The characteristics' own state lives in
/// `characteristicProvider`, keyed so that it survives rediscovery.

abstract class _$Gatt extends $Notifier<List<ServiceGroup>> {
  List<ServiceGroup> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<List<ServiceGroup>, List<ServiceGroup>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<ServiceGroup>, List<ServiceGroup>>,
              List<ServiceGroup>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
