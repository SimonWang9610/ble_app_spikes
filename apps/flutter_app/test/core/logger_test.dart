import 'package:flutter_app/core/log/logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('api logs the call and its outcome, and rethrows failures', () async {
    final logger = Logger();
    final lines = <String>[];
    logger.entries.listen((e) => lines.add('${e.kind.name}: ${e.text}'));

    expect(await logger.api('read', () async => 1), 1);
    await expectLater(logger.api<void>('write', () async => throw StateError('nope')), throwsStateError);
    logger.event('Connected');
    await pumpEventQueue();

    expect(lines, ['api: read', 'api: read ok', 'api: write', 'api: write ✗ Bad state: nope', 'event: Connected']);
  });
}
