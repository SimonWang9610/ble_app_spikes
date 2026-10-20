// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'adapter.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Initializes the manager once and mirrors the adapter state.

@ProviderFor(Adapter)
final adapterProvider = AdapterProvider._();

/// Initializes the manager once and mirrors the adapter state.
final class AdapterProvider extends $NotifierProvider<Adapter, AdapterView> {
  /// Initializes the manager once and mirrors the adapter state.
  AdapterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'adapterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$adapterHash();

  @$internal
  @override
  Adapter create() => Adapter();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AdapterView value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AdapterView>(value),
    );
  }
}

String _$adapterHash() => r'560f2874790711de83d059bb3ee1f60bd8b82557';

/// Initializes the manager once and mirrors the adapter state.

abstract class _$Adapter extends $Notifier<AdapterView> {
  AdapterView build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AdapterView, AdapterView>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AdapterView, AdapterView>,
              AdapterView,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
