/// Binding errors already print as `BleError.platform(message: ...)`.
String describeError(Object error) => '$error';

/// For state reads that are only a nice-to-have (e.g. restoring the MTU when a screen opens).
T? tryOrNull<T>(T Function() body) {
  try {
    return body();
  } catch (_) {
    return null;
  }
}
