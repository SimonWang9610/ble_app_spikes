import 'package:flutter/material.dart';
import 'package:flutter_app/core/theme/app_colors.dart';

abstract final class AppTheme {
  static const _seed = Colors.indigo;

  static final light = ThemeData(colorSchemeSeed: _seed, extensions: const [AppColors.standard]);

  static final dark = ThemeData(
    colorSchemeSeed: _seed,
    brightness: Brightness.dark,
    extensions: const [AppColors.standard],
  );
}
