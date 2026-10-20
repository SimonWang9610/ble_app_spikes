// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reconnector.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Retries a lost link with backoff. Disconnect or a new device rebuilds it, which stops the loop.

@ProviderFor(Reconnector)
final reconnectorProvider = ReconnectorProvider._();

/// Retries a lost link with backoff. Disconnect or a new device rebuilds it, which stops the loop.
final class ReconnectorProvider extends $NotifierProvider<Reconnector, void> {
  /// Retries a lost link with backoff. Disconnect or a new device rebuilds it, which stops the loop.
  ReconnectorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reconnectorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reconnectorHash();

  @$internal
  @override
  Reconnector create() => Reconnector();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$reconnectorHash() => r'1b78b18a27181c3a05b7f8c2e849a2996515c5d5';

/// Retries a lost link with backoff. Disconnect or a new device rebuilds it, which stops the loop.

abstract class _$Reconnector extends $Notifier<void> {
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
