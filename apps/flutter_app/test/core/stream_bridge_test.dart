import 'dart:async';

import 'package:flutter_app/core/ble/stream_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('forwards items and closes the source when the listener cancels', () async {
    final source = StreamController<int>();
    var closed = false;
    final items = <int>[];
    final subscription = bridge(source.stream, () => closed = true).listen(items.add);
    source
      ..add(1)
      ..add(2);
    await pumpEventQueue();
    expect(items, [1, 2]);
    await subscription.cancel();
    expect(closed, isTrue);
  });
}
