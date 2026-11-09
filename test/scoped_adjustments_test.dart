import 'dart:async';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerala_bus_connect/core/data/combine_complete_lists.dart';
import 'package:kerala_bus_connect/features/trips/data/repositories/firebase_trip_repository.dart';

void main() {
  test(
    'passenger delay batches include all requested trips and exclude others',
    () async {
      final db = FakeFirebaseFirestore();
      for (var i = 0; i < 35; i++) {
        await db.collection('trip_adjustments').doc('trip-$i').set({
          'tripId': 'trip-$i',
          'serviceDate': '2026-11-08',
          'scheduleRevision': 'r1',
          'ownerId': i < 10 ? 'owner-a' : 'owner-b',
          'delays': {'a': i},
        });
      }
      await db.collection('trip_adjustments').doc('other-date').set({
        'tripId': 'trip-0',
        'serviceDate': '2026-11-09',
        'scheduleRevision': 'r1',
        'ownerId': 'owner-a',
        'delays': {'a': 99},
      });
      final repository = FirebaseTripRepository(db);
      final ids = List.generate(31, (i) => 'trip-$i');
      final records = await repository
          .watchAdjustments('2026-11-08', tripIds: [...ids, 'trip-0'])
          .first;
      expect(records.map((row) => row.tripId).toSet(), ids.toSet());
      expect(records, hasLength(31));
      expect(
        await repository.watchAdjustments('2026-11-08', tripIds: []).first,
        isEmpty,
      );
      final owned = await repository
          .watchAdjustments('2026-11-08', ownerId: 'owner-a')
          .first;
      expect(owned, hasLength(10));
      expect(owned.every((row) => row.delays['a']! < 10), isTrue);
    },
  );

  test(
    'partial batches never clear an error before the failed batch recovers',
    () async {
      var cancellations = 0;
      final first = StreamController<List<int>>(
        sync: true,
        onCancel: () => cancellations++,
      );
      final second = StreamController<List<int>>(
        sync: true,
        onCancel: () => cancellations++,
      );
      final values = <List<int>>[];
      final errors = <Object>[];
      final sub = combineCompleteLists([
        first.stream,
        second.stream,
      ]).listen(values.add, onError: errors.add);
      first.add([1]);
      await Future<void>.delayed(Duration.zero);
      expect(values, isEmpty);
      second.add([2]);
      await Future<void>.delayed(Duration.zero);
      expect(values.last, [1, 2]);
      second.addError(StateError('offline'));
      first.add([3]);
      await Future<void>.delayed(Duration.zero);
      expect(errors, hasLength(1));
      expect(values, hasLength(1));
      second.add([]);
      await Future<void>.delayed(Duration.zero);
      expect(values.last, [3]);
      await sub.cancel();
      expect(cancellations, 2);
      await first.close();
      await second.close();
    },
  );
}
