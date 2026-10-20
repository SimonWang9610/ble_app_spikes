import 'package:flutter_app/core/log/logger.dart';
import 'package:flutter_app/features/log/application/log_entries.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps the latest 500 lines and hides API lines unless asked', () async {
    final container = ProviderContainer.test();
    container.listen(logEntriesProvider, (_, _) {});
    final logger = container.read(loggerProvider);
    for (var i = 0; i < 510; i++) {
      logger.event('line $i');
    }
    await logger.api('call', () async {});
    await pumpEventQueue();

    final log = container.read(logEntriesProvider);
    expect(log.entries, hasLength(500));
    expect(log.visible.last.text, 'line 509');
    container.read(logEntriesProvider.notifier).setShowApiCalls(true);
    expect(container.read(logEntriesProvider).visible.last.text, 'call ok');
    container.read(logEntriesProvider.notifier).clear();
    expect(container.read(logEntriesProvider).entries, isEmpty);
  });
}
