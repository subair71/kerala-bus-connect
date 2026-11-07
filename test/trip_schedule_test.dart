import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kerala_bus_connect/core/errors/app_failure.dart';
import 'package:kerala_bus_connect/features/timetables/data/models/service_model.dart';
import 'package:kerala_bus_connect/features/trips/data/repositories/firebase_trip_repository.dart';
import 'package:kerala_bus_connect/features/trips/domain/entities/trip_plan.dart';
import 'package:kerala_bus_connect/features/trips/presentation/providers/trip_providers.dart';
import 'support/fakes.dart';

TripPlan example() => TripPlan(
  stops: const [
    TripStop('a', 'Kunnamkulam', 480),
    TripStop('b', 'Marathamcode', 495),
    TripStop('c', 'Pannithadam', 505),
    TripStop('d', 'Erumapetty', 520),
    TripStop('e', 'Wadakkanchery', 540),
  ],
);

void main() {
  test('departure shifts preserve unequal intervals earlier and later', () {
    final plan = example();
    expect(plan.shiftDeparture(485).stops.map((s) => s.minutes), [
      485,
      500,
      510,
      525,
      545,
    ]);
    expect(plan.shiftDeparture(475).stops.map((s) => s.minutes), [
      475,
      490,
      500,
      515,
      535,
    ]);
    expect(plan.stops.first.minutes, 480);
    expect(() => plan.shiftDeparture(-1), throwsA(isA<AppFailure>()));
    expect(() => plan.shiftDeparture(1440), throwsA(isA<AppFailure>()));
  });

  test('return reverses all stops and original intervals independently', () {
    final source = example();
    final result = source.returnTrip(600);
    expect(result.id, '');
    expect(result.stops.map((s) => s.name), [
      'Wadakkanchery',
      'Erumapetty',
      'Pannithadam',
      'Marathamcode',
      'Kunnamkulam',
    ]);
    expect(result.stops.map((s) => s.minutes), [600, 620, 635, 645, 660]);
    final shifted = result.shiftDeparture(610);
    expect(shifted.stops.last.minutes, 670);
    expect(source.stops.first.minutes, 480);
    expect(source.stops.last.minutes, 540);
  });

  test(
    'delays accumulate from selected stops; replacement and removal are idempotent',
    () {
      final plan = example();
      expect(plan.expectedTimes({'a': 5, 'd': 10}), [485, 500, 510, 535, 555]);
      expect(plan.expectedTimes({'a': 5, 'd': 10}), [485, 500, 510, 535, 555]);
      expect(plan.expectedTimes({'a': 5, 'd': 3}), [485, 500, 510, 528, 548]);
      expect(plan.expectedTimes({'d': 10}), [480, 495, 505, 530, 550]);
      expect(plan.expectedTimes({}), [480, 495, 505, 520, 540]);
      expect(
        () => plan.expectedTimes({'missing': 2}),
        throwsA(isA<AppFailure>()),
      );
      expect(() => plan.expectedTimes({'a': -1}), throwsA(isA<AppFailure>()));
    },
  );

  test(
    'midnight, next-day shifts, reverse intervals and delays use absolute minutes',
    () {
      final plan = TripPlan(
        stops: const [
          TripStop('a', 'A', 1430),
          TripStop('b', 'B', 1445),
          TripStop('c', 'C', 1460),
        ],
      );
      expect(() => plan.validate(), returnsNormally);
      expect(plan.shiftDeparture(1420).stops.map((s) => s.minutes), [
        1420,
        1435,
        1450,
      ]);
      expect(plan.shiftDeparture(1439).stops.last.minutes, 1469);
      expect(plan.expectedTimes({'b': 20}), [1430, 1465, 1480]);
      expect(plan.returnTrip(1435).stops.map((s) => s.minutes), [
        1435,
        1450,
        1465,
      ]);
      expect(plan.returnTrip(5).stops.map((s) => s.minutes), [5, 20, 35]);
    },
  );

  test(
    'validation rejects missing, reversed and ambiguous overnight times',
    () {
      for (final stops in [
        <TripStop>[],
        [const TripStop('a', '', 480), const TripStop('b', 'B', 500)],
        [const TripStop('a', 'A', 480), const TripStop('b', 'B', -1)],
        [const TripStop('a', 'A', 480), const TripStop('b', 'B', 479)],
        [const TripStop('a', 'A', 1430), const TripStop('b', 'B', 5)],
        [const TripStop('a', 'A', 0), const TripStop('b', 'B', 1440)],
      ]) {
        expect(
          () => TripPlan(stops: stops).validate(),
          throwsA(isA<AppFailure>()),
        );
      }
    },
  );

  test('draft reorders, renames and removes stable stop identities', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final key = (plan: example(), ownerId: 'owner');
    final sub = container.listen(tripDraftProvider(key), (_, _) {});
    addTearDown(sub.close);
    final draft = container.read(tripDraftProvider(key).notifier);
    draft.move(1, 2);
    draft.rename(2, 'Renamed');
    expect(container.read(tripDraftProvider(key)).plan.stops[2].id, 'b');
    draft.remove(2);
    draft.addStop();
    expect(container.read(tripDraftProvider(key)).plan.stops, hasLength(5));
    draft.step(2);
    expect(container.read(tripDraftProvider(key)).error, isNotNull);
  });

  group('persisted bus trips and date-specific delays', () {
    late FakeFirebaseFirestore db;
    late FirebaseTripRepository repository;
    late BusEntity bus;
    setUp(() async {
      db = FakeFirebaseFirestore();
      repository = FirebaseTripRepository(db);
      await db.collection('businesses').doc(business.id).set({
        'ownerId': 'owner',
        'name': business.name,
      });
      await repository.saveBus('owner', business, 'KL 08 Test');
      final doc = (await db.collection('buses').get()).docs.single;
      bus = BusEntity(
        id: doc.id,
        ownerId: 'owner',
        businessId: business.id,
        name: 'KL 08 Test',
      );
    });

    Future<ServiceModel> read(String id) async => ServiceModel.fromSnapshot(
      await db.collection('services').doc(id).get(),
    );

    test(
      'save, reopen, edit, return and bus rename preserve independent trips',
      () async {
        final id = await repository.saveTrip('owner', business, bus, example());
        final saved = await read(id);
        expect(saved.busId, bus.id);
        expect(saved.stopTimings['Erumapetty'], 520);
        final reopened = TripPlan.fromService(saved);
        final returnedId = await repository.saveTrip(
          'owner',
          business,
          bus,
          reopened.returnTrip(600),
        );
        await repository.saveTrip(
          'owner',
          business,
          bus,
          reopened.shiftDeparture(485),
        );
        expect((await read(id)).stopTimings['Erumapetty'], 525);
        expect((await read(returnedId)).stopTimings['Erumapetty'], 620);
        expect(
          (await db.collection('buses').doc(bus.id).get()).data()!['tripCount'],
          2,
        );
        await repository.saveBus('owner', business, 'Renamed bus', bus: bus);
        expect((await read(id)).busName, 'Renamed bus');
        await expectLater(
          repository.deleteBus('owner', bus),
          throwsA(isA<AppFailure>()),
        );
        await repository.deleteTrip(
          'owner',
          bus,
          TripPlan.fromService(await read(id)),
        );
        await repository.deleteTrip(
          'owner',
          bus,
          TripPlan.fromService(await read(returnedId)),
        );
        await repository.deleteBus('owner', bus);
        expect(
          (await db.collection('buses').doc(bus.id).get()).exists,
          isFalse,
        );
      },
    );

    test(
      'delay saves replace, reopen, reset and never modify another date or schedule',
      () async {
        final id = await repository.saveTrip('owner', business, bus, example());
        final saved = await read(id);
        final trip = TripPlan.fromService(saved);
        DailyAdjustment adjustment(
          Map<String, int> delays, {
          String date = '2026-11-06',
        }) => DailyAdjustment(
          tripId: id,
          serviceDate: date,
          scheduleRevision: trip.revision,
          delays: delays,
        );
        await repository.saveAdjustment(
          'owner',
          bus,
          trip,
          adjustment({'a': 5, 'd': 10}),
        );
        await repository.saveAdjustment(
          'owner',
          bus,
          trip,
          adjustment({'a': 5, 'd': 10}),
        );
        var daily =
            (await repository.watchAdjustments('2026-11-06').first).single;
        expect(daily.apply(saved).expectedTime('Wadakkanchery'), 555);
        expect(daily.apply(saved).scheduledTime('Wadakkanchery'), 540);
        expect(await repository.watchAdjustments('2026-11-07').first, isEmpty);
        expect((await read(id)).stopTimings, saved.stopTimings);
        await repository.saveAdjustment(
          'owner',
          bus,
          trip,
          adjustment({'a': 5, 'd': 3}),
        );
        daily = (await repository.watchAdjustments('2026-11-06').first).single;
        expect(daily.apply(saved).expectedTime('Wadakkanchery'), 548);
        await repository.saveAdjustment(
          'owner',
          bus,
          trip,
          adjustment({'d': 10}),
        );
        daily = (await repository.watchAdjustments('2026-11-06').first).single;
        expect(daily.apply(saved).expectedTime('Kunnamkulam'), 480);
        await repository.saveAdjustment(
          'owner',
          bus,
          trip,
          adjustment({'a': 2}, date: '2026-11-07'),
        );
        await repository.resetAdjustment('owner', bus, trip, '2026-11-06');
        expect(await repository.watchAdjustments('2026-11-06').first, isEmpty);
        expect(
          (await repository.watchAdjustments('2026-11-07').first).single.delays,
          {'a': 2},
        );
      },
    );

    test(
      'no-change save retains adjustments; stale edits and revisions are rejected',
      () async {
        final id = await repository.saveTrip('owner', business, bus, example());
        final saved = await read(id);
        final trip = TripPlan.fromService(saved);
        final daily = DailyAdjustment(
          tripId: id,
          serviceDate: '2026-11-06',
          scheduleRevision: trip.revision,
          delays: {'a': 5},
        );
        await repository.saveTrip('owner', business, bus, trip);
        expect((await read(id)).scheduleRevision, trip.revision);
        await repository.saveTrip(
          'owner',
          business,
          bus,
          trip.shiftDeparture(490),
        );
        expect(daily.apply(await read(id)).hasDailyAdjustment, isFalse);
        await expectLater(
          repository.saveAdjustment('owner', bus, trip, daily),
          throwsA(isA<AppFailure>()),
        );
        await expectLater(
          repository.saveTrip('owner', business, bus, trip),
          throwsA(isA<AppFailure>()),
        );
      },
    );

    test(
      'actual repository rejects wrong owner, bus and service date',
      () async {
        await expectLater(
          repository.saveTrip('attacker', business, bus, example()),
          throwsA(isA<AppFailure>()),
        );
        final id = await repository.saveTrip('owner', business, bus, example());
        final trip = TripPlan.fromService(await read(id));
        await expectLater(
          repository.deleteTrip('attacker', bus, trip),
          throwsA(isA<AppFailure>()),
        );
        await expectLater(
          repository.resetAdjustment('owner', bus, trip, '2026-02-31'),
          throwsA(isA<AppFailure>()),
        );
      },
    );
  });
}
