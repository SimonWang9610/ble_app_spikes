// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nearby.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Nearby devices, for the Nearby screen only; one scan at a time, stopped when the screen goes away.

@ProviderFor(Nearby)
final nearbyProvider = NearbyProvider._();

/// Nearby devices, for the Nearby screen only; one scan at a time, stopped when the screen goes away.
final class NearbyProvider extends $NotifierProvider<Nearby, NearbyState> {
  /// Nearby devices, for the Nearby screen only; one scan at a time, stopped when the screen goes away.
  NearbyProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'nearbyProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$nearbyHash();

  @$internal
  @override
  Nearby create() => Nearby();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NearbyState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NearbyState>(value),
    );
  }
}

String _$nearbyHash() => r'14e719ab4e3957a59a856a4df7a69789d3b83a4a';

/// Nearby devices, for the Nearby screen only; one scan at a time, stopped when the screen goes away.

abstract class _$Nearby extends $Notifier<NearbyState> {
  NearbyState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<NearbyState, NearbyState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<NearbyState, NearbyState>,
              NearbyState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
