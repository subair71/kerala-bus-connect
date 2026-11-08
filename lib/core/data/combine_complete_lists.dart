import 'dart:async';

/// Emit only after every source has a successful value. A failed source must
/// recover before other updates may replace the error with a partial result.
Stream<List<T>> combineCompleteLists<T>(List<Stream<List<T>>> sources) {
  if (sources.isEmpty) return Stream.value(const []);
  late StreamController<List<T>> controller;
  final subscriptions = <StreamSubscription<List<T>>>[];
  final values = <int, List<T>>{};
  var done = 0;
  controller = StreamController<List<T>>(
    onListen: () {
      for (var i = 0; i < sources.length; i++) {
        final index = i;
        subscriptions.add(
          sources[i].listen(
            (rows) {
              values[index] = rows;
              if (values.length == sources.length) {
                controller.add(List.unmodifiable([
                  for (var j = 0; j < sources.length; j++) ...values[j]!,
                ]));
              }
            },
            onError: (Object error, StackTrace stack) {
              values.remove(index);
              controller.addError(error, stack);
            },
            onDone: () {
              done++;
              if (done == sources.length) controller.close();
            },
          ),
        );
      }
    },
    onCancel: () async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    },
  );
  return controller.stream;
}
