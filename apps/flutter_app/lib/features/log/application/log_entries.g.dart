// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'log_entries.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The log panel's state: the latest entries of the [Logger] and the API-calls filter.

@ProviderFor(LogEntries)
final logEntriesProvider = LogEntriesProvider._();

/// The log panel's state: the latest entries of the [Logger] and the API-calls filter.
final class LogEntriesProvider extends $NotifierProvider<LogEntries, LogState> {
  /// The log panel's state: the latest entries of the [Logger] and the API-calls filter.
  LogEntriesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'logEntriesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$logEntriesHash();

  @$internal
  @override
  LogEntries create() => LogEntries();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LogState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LogState>(value),
    );
  }
}

String _$logEntriesHash() => r'7fb4c0f06996473c259aaf9059dfddb77b818d7f';

/// The log panel's state: the latest entries of the [Logger] and the API-calls filter.

abstract class _$LogEntries extends $Notifier<LogState> {
  LogState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<LogState, LogState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<LogState, LogState>,
              LogState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
