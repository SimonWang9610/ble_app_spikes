import 'package:flutter_app/core/utils/bytes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseValue', () {
    test('reads spaced, packed and 0x-prefixed hex', () {
      expect(parseValue('01 02 0a', ValueFormat.hex), [1, 2, 10]);
      expect(parseValue('01020A', ValueFormat.hex), [1, 2, 10]);
      expect(parseValue('0x01 0x02', ValueFormat.hex), [1, 2]);
    });

    test('rejects odd digit counts and non-hex', () {
      expect(() => parseValue('012', ValueFormat.hex), throwsFormatException);
      expect(() => parseValue('zz', ValueFormat.hex), throwsFormatException);
    });

    test('encodes text as UTF-8', () => expect(parseValue('hé', ValueFormat.utf8), [0x68, 0xc3, 0xa9]));
  });

  group('display', () {
    test('marks empty values', () => expect(display([]), '(empty)'));
    test(
      'decodes 4-byte little-endian counters',
      () => expect(display([42, 0, 0, 0], asCounter: true), '2a 00 00 00 = 42'),
    );
    test('shows printable bytes as text', () => expect(display([0x68, 0x69]), '68 69 "hi"'));
    test('shows other bytes as hex only', () => expect(display([0, 255]), '00 ff'));
  });

  test('toUtf8 returns null for invalid UTF-8', () {
    expect(toUtf8([0x68, 0x69]), 'hi');
    expect(toUtf8([0xff]), isNull);
  });
}
