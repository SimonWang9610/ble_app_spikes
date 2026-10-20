import 'package:flutter/material.dart';

/// Status colours the Material scheme has no slot for.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.success,
    required this.warning,
    required this.danger,
    required this.muted,
    required this.value,
  });

  static const standard = AppColors(
    success: Colors.green,
    warning: Colors.orange,
    danger: Colors.red,
    muted: Colors.grey,
    value: Colors.blue,
  );

  final Color success;
  final Color warning;
  final Color danger;
  final Color muted;
  final Color value;

  @override
  AppColors copyWith({Color? success, Color? warning, Color? danger, Color? muted, Color? value}) => AppColors(
    success: success ?? this.success,
    warning: warning ?? this.warning,
    danger: danger ?? this.danger,
    muted: muted ?? this.muted,
    value: value ?? this.value,
  );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      value: Color.lerp(value, other.value, t)!,
    );
  }
}

extension AppColorsContext on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>() ?? AppColors.standard;
}
