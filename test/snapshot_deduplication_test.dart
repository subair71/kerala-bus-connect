import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerala_bus_connect/core/data/distinct_records.dart';
import 'package:kerala_bus_connect/features/timetables/domain/entities/service_entity.dart';
import 'support/fakes.dart';

void main() {
  test(
    'equivalent schedules emit once; updates and removals still emit',
    () async {
      final input = StreamController<List<ServiceEntity>>(sync: true);
      final received = <List<ServiceEntity>>[];
      final sub = input.stream
          .transform(const DistinctRecords<ServiceEntity>())
          .listen(received.add);

      input.add([service('one')]);
      input.add([service('one')]);
      expect(received, hasLength(1));
      input.add([service('one', departure: 600)]);
      input.add([]);
      input.add([]);
      expect(received, hasLength(3));
      expect(received[1].single.departureMinutes, 600);
      expect(received.last, isEmpty);

      await input.close();
      await sub.cancel();
    },
  );

  test('identical data after an error restores the successful state', () async {
    final input = StreamController<List<int>>(sync: true);
    final received = <List<int>>[];
    final errors = <Object>[];
    final sub = input.stream
        .transform(const DistinctRecords<int>())
        .listen(received.add, onError: errors.add);

    input.add([1]);
    input.addError(StateError('offline'));
    input.add([1]);
    input.add([1]);
    expect(errors, hasLength(1));
    expect(received, [
      [1],
      [1],
    ]);

    await input.close();
    await sub.cancel();
  });

  test('order changes and independent subscriptions are preserved', () async {
    const transformer = DistinctRecords<int>();
    final first = await Stream.fromIterable([
      [1, 2],
      [1, 2],
      [2, 1],
    ]).transform(transformer).toList();
    final second = await Stream.value([2, 1]).transform(transformer).toList();
    expect(first, [
      [1, 2],
      [2, 1],
    ]);
    expect(second, [
      [2, 1],
    ]);
  });

  test('cancellation releases the source listener', () async {
    var cancelled = false;
    final input = StreamController<List<int>>(onCancel: () => cancelled = true);
    final sub = input.stream
        .transform(const DistinctRecords<int>())
        .listen((_) {});
    await sub.cancel();
    expect(cancelled, isTrue);
    await input.close();
  });
}
