// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'characteristic.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// One characteristic's latest value, busy / error and subscription flag. Kept while its device is the
/// current one; after that it starts empty and goes once nothing shows it.

@ProviderFor(Characteristic)
final characteristicProvider = CharacteristicFamily._();

/// One characteristic's latest value, busy / error and subscription flag. Kept while its device is the
/// current one; after that it starts empty and goes once nothing shows it.
final class CharacteristicProvider
    extends $NotifierProvider<Characteristic, CharState> {
  /// One characteristic's latest value, busy / error and subscription flag. Kept while its device is the
  /// current one; after that it starts empty and goes once nothing shows it.
  CharacteristicProvider._({
    required CharacteristicFamily super.from,
    required CharKey super.argument,
  }) : super(
         retry: null,
         name: r'characteristicProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$characteristicHash();

  @override
  String toString() {
    return r'characteristicProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  Characteristic create() => Characteristic();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CharState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CharState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CharacteristicProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$characteristicHash() => r'8ef7f6aca1a06b26862ca5ed2984d7714ba813ab';

/// One characteristic's latest value, busy / error and subscription flag. Kept while its device is the
/// current one; after that it starts empty and goes once nothing shows it.

final class CharacteristicFamily extends $Family
    with
        $ClassFamilyOverride<
          Characteristic,
          CharState,
          CharState,
          CharState,
          CharKey
        > {
  CharacteristicFamily._()
    : super(
        retry: null,
        name: r'characteristicProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One characteristic's latest value, busy / error and subscription flag. Kept while its device is the
  /// current one; after that it starts empty and goes once nothing shows it.

  CharacteristicProvider call(CharKey key) =>
      CharacteristicProvider._(argument: key, from: this);

  @override
  String toString() => r'characteristicProvider';
}

/// One characteristic's latest value, busy / error and subscription flag. Kept while its device is the
/// current one; after that it starts empty and goes once nothing shows it.

abstract class _$Characteristic extends $Notifier<CharState> {
  late final _$args = ref.$arg as CharKey;
  CharKey get key => _$args;

  CharState build(CharKey key);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<CharState, CharState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CharState, CharState>,
              CharState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
