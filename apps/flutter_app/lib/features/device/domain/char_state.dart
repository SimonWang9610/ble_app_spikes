import 'dart:typed_data';

import 'package:flutter_app/features/device/domain/char_key.dart';

enum ValueSource { read, received, written }

const _keep = Object();

/// One characteristic as the user sees it. The write form is not here: it belongs to the sheet.
class CharState {
  const CharState(
    this.key, {
    this.latest,
    this.latestTime,
    this.source,
    this.subscribed = false,
    this.receivedCount = 0,
    this.busy,
    this.error,
  });

  final CharKey key;
  final Uint8List? latest;
  final DateTime? latestTime;
  final ValueSource? source;

  /// What the user asked for; re-applied after a reconnect.
  final bool subscribed;
  final int receivedCount;
  final String? busy;
  final String? error;

  String show(List<int> value) => key.show(value);

  /// `busy` and `error` take null to clear, so they use a sentinel for "unchanged".
  CharState copyWith({
    Uint8List? latest,
    DateTime? latestTime,
    ValueSource? source,
    bool? subscribed,
    int? receivedCount,
    Object? busy = _keep,
    Object? error = _keep,
  }) => CharState(
    key,
    latest: latest ?? this.latest,
    latestTime: latestTime ?? this.latestTime,
    source: source ?? this.source,
    subscribed: subscribed ?? this.subscribed,
    receivedCount: receivedCount ?? this.receivedCount,
    busy: busy == _keep ? this.busy : busy as String?,
    error: error == _keep ? this.error : error as String?,
  );
}
