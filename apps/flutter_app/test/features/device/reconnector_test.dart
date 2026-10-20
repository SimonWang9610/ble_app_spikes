import 'package:flutter_app/features/device/application/reconnector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer.test();
    container.listen(reconnectorProvider, (_, _) {});
  });

  test('returns how long it took once an attempt succeeds', () async {
    final attempts = <int>[];
    final took = await container.read(reconnectorProvider.notifier).start((n) async {
      attempts.add(n);
      if (n < 2) throw StateError('down');
      return true;
    });
    expect(attempts, [1, 2]);
    expect(took, greaterThanOrEqualTo(const Duration(seconds: 1)));
  });

  test('returns null when the session ends during an attempt', () async {
    final took = await container.read(reconnectorProvider.notifier).start((_) async => false);
    expect(took, isNull);
  });

  test('rebuilding the provider cuts the backoff wait short', () async {
    final watch = Stopwatch()..start();
    final result = container.read(reconnectorProvider.notifier).start((_) async => throw StateError('down'));
    await pumpEventQueue();
    container.invalidate(reconnectorProvider);
    container.read(reconnectorProvider);
    expect(await result, isNull);
    expect(watch.elapsed, lessThan(const Duration(milliseconds: 500)));
  });
}
