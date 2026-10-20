import 'dart:async';

/// Re-wraps a binding stream so its object is closed when the listener cancels.
Stream<T> bridge<T>(Stream<T> items, void Function() close) {
  StreamSubscription<T>? subscription;
  late final StreamController<T> controller;
  controller = StreamController<T>(
    onListen: () => subscription = items.listen(controller.add, onError: controller.addError, onDone: controller.close),
    onCancel: () async {
      await subscription?.cancel();
      close();
    },
  );
  return controller.stream;
}
