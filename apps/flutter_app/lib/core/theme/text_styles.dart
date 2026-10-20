import 'package:flutter/painting.dart';

abstract final class AppTextStyles {
  /// For UUIDs, bytes and log lines.
  static const mono = TextStyle(fontFamily: 'Menlo', fontFamilyFallback: ['Courier', 'monospace']);
}
