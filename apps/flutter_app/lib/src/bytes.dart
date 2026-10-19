import 'dart:convert';
import 'dart:typed_data';

enum ValueFormat { hex, utf8 }

/// "01 02 0a"
String toHex(List<int> bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');

/// The bytes as text, or null if they aren't valid UTF-8.
String? toUtf8(List<int> bytes) {
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return null;
  }
}

/// Parses "01 02 0a", "01020a" or "0x01 0x02" (hex), or encodes the text (utf8).
Uint8List parseValue(String text, ValueFormat format) {
  if (format == ValueFormat.utf8) return Uint8List.fromList(utf8.encode(text));
  final digits = text.replaceAll('0x', '').replaceAll(RegExp(r'\s'), '');
  if (digits.length.isOdd) throw const FormatException('odd number of hex digits');
  return Uint8List.fromList([
    for (var i = 0; i < digits.length; i += 2)
      int.tryParse(digits.substring(i, i + 2), radix: 16) ??
          (throw FormatException('not hex: ${digits.substring(i, i + 2)}')),
  ]);
}

/// "2a 00 00 00 = 42" for 4-byte counters, `68 69 "hi"` for plain text, hex otherwise.
String display(List<int> bytes, {bool asCounter = false}) {
  if (bytes.isEmpty) return '(empty)';
  final hex = toHex(bytes);
  if (asCounter && bytes.length == 4) {
    return '$hex = ${bytes[0] | bytes[1] << 8 | bytes[2] << 16 | bytes[3] << 24}';
  }
  final printable = bytes.every((b) => b >= 0x20 && b < 0x7f);
  return printable ? '$hex "${String.fromCharCodes(bytes)}"' : hex;
}
