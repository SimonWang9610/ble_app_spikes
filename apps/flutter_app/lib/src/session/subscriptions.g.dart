// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subscriptions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Notify / indicate value streams of the current device, and which characteristics the user wants them for.
/// No UI state: a characteristic shows its own `subscribed` flag and values.

@ProviderFor(Subscriptions)
final subscriptionsProvider = SubscriptionsProvider._();

/// Notify / indicate value streams of the current device, and which characteristics the user wants them for.
/// No UI state: a characteristic shows its own `subscribed` flag and values.
final class SubscriptionsProvider
    extends $NotifierProvider<Subscriptions, void> {
  /// Notify / indicate value streams of the current device, and which characteristics the user wants them for.
  /// No UI state: a characteristic shows its own `subscribed` flag and values.
  SubscriptionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'subscriptionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$subscriptionsHash();

  @$internal
  @override
  Subscriptions create() => Subscriptions();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$subscriptionsHash() => r'460a1449e1fcbd0daaf3baf882545a2303286f63';

/// Notify / indicate value streams of the current device, and which characteristics the user wants them for.
/// No UI state: a characteristic shows its own `subscribed` flag and values.

abstract class _$Subscriptions extends $Notifier<void> {
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
