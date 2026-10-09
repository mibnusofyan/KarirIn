import 'dart:async';

/// Emits [current] on listen, then every event of [changes]. Subscribes to [changes] synchronously on listen,
/// so no change made right after listening is lost (unlike an `async*` generator).
Stream<T> currentThenChanges<T>(T Function() current, Stream<T> changes) {
  StreamSubscription<T>? sub;
  late final StreamController<T> controller;
  controller = StreamController<T>(
    onListen: () {
      controller.add(current());
      sub = changes.listen(controller.add, onError: controller.addError);
    },
    onCancel: () => sub?.cancel(),
  );
  return controller.stream;
}
