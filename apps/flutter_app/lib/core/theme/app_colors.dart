import 'package:flutter/material.dart';

/// Status and operation colours the Material scheme has no slot for.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.success,
    required this.warning,
    required this.danger,
    required this.muted,
    required this.value,
    required this.read,
    required this.write,
    required this.writeWithoutResponse,
    required this.notify,
    required this.indicate,
  });

  static const standard = AppColors(
    success: Colors.green,
    warning: Colors.orange,
    danger: Colors.red,
    muted: Colors.grey,
    value: Colors.blue,
    // The same as the Swift app's operation pills.
    read: Color(0xFF007AFF),
    write: Color(0xFFAF52DE),
    writeWithoutResponse: Color(0xFF5856D6),
    notify: Color(0xFF34C759),
    indicate: Color(0xFF30B0C7),
  );

  final Color success;
  final Color warning;
  final Color danger;
  final Color muted;
  final Color value;
  final Color read;
  final Color write;
  final Color writeWithoutResponse;
  final Color notify;
  final Color indicate;

  @override
  AppColors copyWith({
    Color? success,
    Color? warning,
    Color? danger,
    Color? muted,
    Color? value,
    Color? read,
    Color? write,
    Color? writeWithoutResponse,
    Color? notify,
    Color? indicate,
  }) => AppColors(
    success: success ?? this.success,
    warning: warning ?? this.warning,
    danger: danger ?? this.danger,
    muted: muted ?? this.muted,
    value: value ?? this.value,
    read: read ?? this.read,
    write: write ?? this.write,
    writeWithoutResponse: writeWithoutResponse ?? this.writeWithoutResponse,
    notify: notify ?? this.notify,
    indicate: indicate ?? this.indicate,
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
      read: Color.lerp(read, other.read, t)!,
      write: Color.lerp(write, other.write, t)!,
      writeWithoutResponse: Color.lerp(writeWithoutResponse, other.writeWithoutResponse, t)!,
      notify: Color.lerp(notify, other.notify, t)!,
      indicate: Color.lerp(indicate, other.indicate, t)!,
    );
  }
}

extension AppColorsContext on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>() ?? AppColors.standard;
}
