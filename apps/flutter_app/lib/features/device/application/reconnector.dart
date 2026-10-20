import 'dart:async';
import 'package:flutter_app/features/device/application/current_device.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'reconnector.g.dart';

/// Retries a lost link with backoff. Disconnect or a new device rebuilds it, which stops the loop.
@Riverpod(keepAlive: true)
class Reconnector extends _$Reconnector {
  static const _delays = [1, 2, 4, 8, 10];
  static const limit = Duration(seconds: 60);

  Timer? _timer;
  Completer<void>? _wait;
  bool _stopped = false;

  @override
  void build() {
    ref.watch(currentDeviceProvider);
    ref.onDispose(_stop);
  }

  /// Runs `attempt` until it succeeds or [limit] passes: how long that took, or null after giving up or
  /// being stopped. A failed attempt throws (it logs and drops its half-open link first).
  Future<Duration?> start(Future<bool> Function(int attempt) attempt) async {
    _stopped = false;
    final watch = Stopwatch()..start();
    for (var n = 1; ; n++) {
      try {
        return await attempt(n) ? watch.elapsed : null;
      } catch (_) {
        // Try again below.
      }
      final delay = Duration(seconds: _delays[(n - 1).clamp(0, _delays.length - 1)]);
      if (watch.elapsed + delay > limit) return null;
      await _sleep(delay);
      if (_stopped) return null;
    }
  }

  /// A wait begun after [_stop] ends at once, so a loop whose attempt failed late still sees the flag
  /// before a new [start] can reset it.
  Future<void> _sleep(Duration delay) {
    if (_stopped) return Future.value();
    final wait = _wait = Completer<void>();
    _timer = Timer(delay, wait.complete);
    return wait.future;
  }

  /// Cuts the pending wait short; the loop wakes in a microtask, well before any new [start].
  void _stop() {
    _stopped = true;
    _timer?.cancel();
    _timer = null;
    if (_wait case final wait? when !wait.isCompleted) wait.complete();
    _wait = null;
  }
}
