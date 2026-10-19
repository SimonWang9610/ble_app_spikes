/// The fixture's name and UUIDs (docs/test-plan.md), used for the default scan filter and labels.
abstract final class Fixture {
  static const name = 'HM-BLE-FIXTURE';

  static const _labels = {
    'f0e10000-5a3e-4c1a-9d2b-1b2c3d4e5f60': 'DATA',
    'f0e10001-5a3e-4c1a-9d2b-1b2c3d4e5f60': 'VALUE',
    'f0e10100-5a3e-4c1a-9d2b-1b2c3d4e5f60': 'STREAM',
    'f0e10101-5a3e-4c1a-9d2b-1b2c3d4e5f60': 'NOTIFY',
    'f0e10102-5a3e-4c1a-9d2b-1b2c3d4e5f60': 'INDICATE',
  };

  /// "VALUE" for fixture UUIDs, null otherwise.
  static String? nameOf(String uuid) => _labels[uuid];

  /// "VALUE" for fixture UUIDs, "f0e1ffff…" otherwise.
  static String shortName(String uuid) => _labels[uuid] ?? '${uuid.substring(0, 8)}…';

  /// "VALUE (f0e10001…)" for fixture UUIDs, the UUID otherwise.
  static String label(String uuid) {
    final name = _labels[uuid];
    return name == null ? uuid : '$name (${uuid.substring(0, 8)}…)';
  }
}
