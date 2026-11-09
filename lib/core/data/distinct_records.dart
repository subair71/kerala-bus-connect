import 'dart:async';

/// Suppresses equivalent snapshots without hiding recovery after an error.
/// Records must be immutable and implement value equality.
class DistinctRecords<T> extends StreamTransformerBase<List<T>, List<T>> {
  const DistinctRecords();

  @override
  Stream<List<T>> bind(Stream<List<T>> stream) {
    List<T>? previous;
    return stream.transform(
      StreamTransformer<List<T>, List<T>>.fromHandlers(
        handleData: (records, sink) {
          final last = previous;
          if (last != null && _same(last, records)) return;
          previous = List<T>.unmodifiable(records);
          sink.add(previous!);
        },
        handleError: (Object error, StackTrace stack, sink) {
          previous = null;
          sink.addError(error, stack);
        },
      ),
    );
  }

  bool _same(List<T> first, List<T> second) {
    if (first.length != second.length) return false;
    for (var i = 0; i < first.length; i++) {
      if (first[i] != second[i]) return false;
    }
    return true;
  }
}
