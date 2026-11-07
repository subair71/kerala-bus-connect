import 'dart:async';
import 'dart:math';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kerala_bus_connect/core/providers/cache_lifetime.dart';
import 'package:kerala_bus_connect/core/theme/app_theme.dart';
import 'package:kerala_bus_connect/features/auth/domain/entities/auth_user.dart';
import 'package:kerala_bus_connect/features/auth/presentation/providers/auth_providers.dart';
import 'package:kerala_bus_connect/features/crew/domain/entities/crew_assignment.dart';
import 'package:kerala_bus_connect/features/crew/presentation/providers/crew_providers.dart';
import 'package:kerala_bus_connect/features/owner/presentation/pages/owner_page.dart';
import 'package:kerala_bus_connect/features/passenger/domain/services/departure_order.dart';
import 'package:kerala_bus_connect/features/passenger/presentation/providers/search_providers.dart';
import 'package:kerala_bus_connect/features/timetables/domain/entities/service_entity.dart';
import 'package:kerala_bus_connect/features/timetables/presentation/providers/timetable_providers.dart';
import 'package:kerala_bus_connect/features/tracking/domain/entities/tracking_preview.dart';
import 'package:kerala_bus_connect/features/tracking/domain/repositories/tracking_repository.dart';
import 'package:kerala_bus_connect/features/tracking/presentation/pages/tracking_page.dart';
import 'package:kerala_bus_connect/features/tracking/presentation/providers/tracking_providers.dart';
import 'package:kerala_bus_connect/features/trips/presentation/providers/trip_providers.dart';
import 'support/fakes.dart';
import 'trip_dashboard_test.dart' show bus;
import 'trip_passenger_test.dart' show managed;
import 'trip_schedule_test.dart' show example;

class CountedService extends ServiceEntity {
  static int lookups = 0;
  CountedService(int number)
    : super(
        id: '$number',
        ownerId: 'owner',
        businessId: 'business',
        routeId: 'route',
        businessName: 'Operator',
        routeName: 'Aluva - Kaloor',
        busName: 'Bus $number',
        stops: const ['Aluva', 'Kalamassery', 'Kaloor'],
        departureMinutes: number,
        stopTimings: {
          'Aluva': number,
          'Kalamassery': number + 15,
          'Kaloor': number + 30,
        },
        offDays: const [],
      );
  @override
  int? expectedTime(String stop) {
    lookups++;
    return super.expectedTime(stop);
  }
}

class CountingTrackingRepository implements TrackingRepository {
  int requests = 0, cancellations = 0;
  late final changes = StreamController<List<TrackingPreview>>.broadcast(
    onCancel: () => cancellations++,
  );
  @override
  Stream<List<TrackingPreview>> watch() {
    requests++;
    return changes.stream;
  }
}

class CountingOwnerRepository extends FakeTransitRepository {
  final requests = <String>[];
  final cancelledOwners = <String>[];
  final streams = <String, StreamController<List<ServiceEntity>>>{};
  @override
  Stream<List<ServiceEntity>> getOwnerServices(String ownerId) {
    requests.add(ownerId);
    return streams
        .putIfAbsent(
          ownerId,
          () => StreamController<List<ServiceEntity>>.broadcast(
            onCancel: () => cancelledOwners.add(ownerId),
          ),
        )
        .stream;
  }
}

void main() {
  test(
    'boarding sort resolves each service once and preserves accurate ordering',
    () {
      final records = List.generate(2000, CountedService.new)
        ..shuffle(Random(71));
      CountedService.lookups = 0;
      final baselineWatch = Stopwatch()..start();
      final baseline = [...records]
        ..sort(
          (a, b) => a
              .expectedTime('Kalamassery')!
              .compareTo(b.expectedTime('Kalamassery')!),
        );
      baselineWatch.stop();
      final baselineLookups = CountedService.lookups;
      CountedService.lookups = 0;
      final optimizedWatch = Stopwatch()..start();
      final ordered = orderDepartures(records, ' KALAM ');
      optimizedWatch.stop();
      expect(ordered.map((s) => s.id), baseline.map((s) => s.id));
      expect(CountedService.lookups, records.length);
      expect(baselineLookups, greaterThan(records.length * 2));
      expect(
        orderDepartures([
          service('midnight', departure: 0),
          service('later'),
        ], '').first.id,
        'midnight',
      );
      expect(
        orderDepartures([service('one'), service('two')], '').map((s) => s.id),
        ['one', 'two'],
      );
      print(
        'PERFORMANCE boarding sort: ${records.length} records; '
        'lookups $baselineLookups -> ${CountedService.lookups}; '
        'baseline ${baselineWatch.elapsedMicroseconds}us, optimized ${optimizedWatch.elapsedMicroseconds}us (test runtime).',
      );
    },
  );

  test(
    'tracking shares cached live subscriptions, then releases idle resources',
    () async {
      final repository = CountingTrackingRepository();
      final container = ProviderContainer(
        overrides: [
          trackingRepositoryProvider.overrideWithValue(repository),
          liveDataCacheDurationProvider.overrideWithValue(
            const Duration(milliseconds: 100),
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await repository.changes.close();
      });
      final first = container.listen(liveTrackingProvider, (_, _) {});
      repository.changes.add([
        const TrackingPreview('Bus', ['A', 'B'], 0),
      ]);
      await container.read(liveTrackingProvider.future);
      final shared = container.listen(trackingDataProvider, (_, _) {});
      expect(repository.requests, 1);
      first.close();
      shared.close();
      await container.pump();
      final reopened = container.listen(liveTrackingProvider, (_, _) {});
      expect(repository.requests, 1);
      expect(
        container.read(liveTrackingProvider).requireValue.single.vehicle,
        'Bus',
      );
      reopened.close();
      await container.pump();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await container.pump();
      expect(repository.cancellations, 1);
    },
  );

  test(
    'cached owner streams are cleared on account changes even while off screen',
    () async {
      final auth = FakeAuthRepository(
        user: const AuthUser(id: 'owner', email: 'one@test.com'),
      );
      final repository = CountingOwnerRepository();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          transitRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await auth.changes.close();
        for (final stream in repository.streams.values) {
          await stream.close();
        }
      });
      await container.read(authUserProvider.future);
      final sub = container.listen(ownerServicesProvider, (_, _) {});
      repository.streams['owner']!.add([service('private')]);
      await container.read(ownerServicesProvider.future);
      sub.close();
      await container.pump();
      await auth.signOut();
      await Future<void>.delayed(Duration.zero);
      await container.pump();
      expect(await container.read(ownerServicesProvider.future), isEmpty);
      expect(repository.cancelledOwners, contains('owner'));
      auth.user = const AuthUser(id: 'second', email: 'two@test.com');
      auth.changes.add(auth.user);
      final next = container.listen(ownerServicesProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(ownerServicesProvider).asData?.value ?? [],
        isEmpty,
      );
      repository.streams['second']!.add([]);
      expect(await container.read(ownerServicesProvider.future), isEmpty);
      expect(repository.requests, ['owner', 'second']);
      next.close();
    },
  );

  test('the normalized search index survives a brief tab switch', () async {
    final repository = FakeTransitRepository(services: [service('one')]);
    final container = ProviderContainer(
      overrides: [
        transitRepositoryProvider.overrideWithValue(repository),
        catalogCacheDurationProvider.overrideWithValue(
          const Duration(milliseconds: 100),
        ),
      ],
    );
    addTearDown(container.dispose);
    final first = container.listen(serviceIndexProvider, (_, _) {});
    await container.read(publishedServicesProvider.future);
    final index = container.read(serviceIndexProvider).requireValue;
    first.close();
    await container.pump();
    final next = container.listen(serviceIndexProvider, (_, _) {});
    expect(
      identical(container.read(serviceIndexProvider).requireValue, index),
      isTrue,
    );
    expect(repository.publishedRequests, 1);
    next.close();
  });

  test(
    'crew query debounces typing, keeps shifts immediate and cancels on disposal',
    () {
      fakeAsync((async) {
        final container = ProviderContainer(
          overrides: [
            liveCrewProvider.overrideWithValue(
              const AsyncData([
                CrewAssignment('Asha', 'Driver', 'KL-01', 'Morning', '08:00'),
                CrewAssignment(
                  'Binu',
                  'Conductor',
                  'KL-02',
                  'Evening',
                  '17:00',
                ),
              ]),
            ),
          ],
        );
        final sub = container.listen(filteredCrewProvider, (_, _) {});
        final controller = container.read(crewFilterProvider.notifier);
        controller.search('d');
        async.elapse(const Duration(milliseconds: 100));
        controller.search('driver');
        async.elapse(const Duration(milliseconds: 199));
        expect(container.read(filteredCrewProvider), hasLength(2));
        async.elapse(const Duration(milliseconds: 1));
        expect(container.read(filteredCrewProvider).single.name, 'Asha');
        controller.shift('Evening');
        expect(container.read(filteredCrewProvider), isEmpty);
        controller.search('pending');
        sub.close();
        container.dispose();
        async.elapse(const Duration(seconds: 1));
      });
    },
  );

  test('trip text edits only invalidate the affected editor state', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final args = (plan: example(), ownerId: 'owner');
    var structuralChanges = 0;
    final sub = container.listen(
      tripEditorStructureProvider(args),
      (_, _) => structuralChanges++,
    );
    final controller = container.read(tripDraftProvider(args).notifier);
    controller.rename(1, 'Renamed stop');
    expect(
      container.read(tripDraftProvider(args)).plan.stops[1].name,
      'Renamed stop',
    );
    expect(structuralChanges, 0);
    controller.move(1, 2);
    container.read(tripEditorStructureProvider(args));
    expect(structuralChanges, 1);
    controller.step(1);
    container.read(tripEditorStructureProvider(args));
    final changesBeforeNote = structuralChanges;
    controller.note('Updated passenger note');
    expect(
      container.read(tripDraftProvider(args)).plan.note,
      'Updated passenger note',
    );
    expect(structuralChanges, changesBeforeNote);
    sub.close();
  });

  testWidgets('tracking builds only the visible part of a long stop list', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          liveTrackingProvider.overrideWithValue(
            AsyncData([
              TrackingPreview(
                'Long route',
                List.generate(500, (i) => 'Stop $i'),
                0,
                id: 'long',
              ),
            ]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: TrackingPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ListTile).evaluate().length, lessThan(30));
    expect(find.text('Stop 499'), findsNothing);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -1500));
    await tester.pumpAndSettle();
    expect(find.byType(ListTile).evaluate().length, lessThan(30));
    expect(tester.takeException(), isNull);
  });

  testWidgets('owner dashboard lazily renders large trip lists', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authUserProvider.overrideWithValue(
            const AsyncData(AuthUser(id: 'owner', email: 'owner@test.com')),
          ),
          ownerBusinessesProvider.overrideWithValue(
            const AsyncData([business]),
          ),
          ownerBusesProvider.overrideWith((ref, id) => Stream.value([bus])),
          ownerServicesProvider.overrideWithValue(
            AsyncData(List.generate(200, (i) => managed('trip-$i', i * 5))),
          ),
          dailyAdjustmentsProvider.overrideWith(
            (ref, date) => Stream.value([]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: OwnerPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('Edit trip').evaluate().length, inInclusiveRange(1, 10));
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -1500));
    await tester.pumpAndSettle();
    expect(find.text('Edit trip').evaluate().length, inInclusiveRange(1, 10));
    expect(tester.takeException(), isNull);
  });
}
