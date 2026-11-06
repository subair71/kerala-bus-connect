import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kerala_bus_connect/core/providers/clock_provider.dart';
import 'package:kerala_bus_connect/features/passenger/presentation/providers/search_providers.dart';
import 'package:kerala_bus_connect/features/timetables/data/models/service_model.dart';
import 'package:kerala_bus_connect/features/timetables/presentation/providers/timetable_providers.dart';
import 'package:kerala_bus_connect/features/trips/domain/entities/trip_plan.dart';
import 'package:kerala_bus_connect/features/trips/presentation/providers/trip_providers.dart';

ServiceModel managed(String id, int departure) => ServiceModel.fromMap(id, {
  'ownerId': 'owner',
  'businessId': 'business',
  'busId': 'bus',
  'busName': id,
  'routeId': 'route',
  'routeName': 'A → C',
  'stops': ['A', 'B', 'C'],
  'stopIds': ['a', 'b', 'c'],
  'stopTimings': {'A': departure, 'B': departure + 15, 'C': departure + 40},
  'departureMinutes': departure,
  'scheduleRevision': 'r1',
  'offDays': [],
  'published': true,
});

void main() {
  test(
    'passenger results use saved date delays and sort by expected boarding time',
    () async {
      final today = DateTime(2026, 11, 6);
      final delay = DailyAdjustment(
        tripId: 'first',
        serviceDate: '2026-11-06',
        scheduleRevision: 'r1',
        delays: {'b': 20},
      );
      final container = ProviderContainer(
        overrides: [
          clockProvider.overrideWithValue(AsyncData(today)),
          publishedServicesProvider.overrideWith(
            (ref) =>
                Stream.value([managed('first', 480), managed('second', 490)]),
          ),
          dailyAdjustmentsProvider.overrideWith(
            (ref, date) => Stream.value(
              date == '2026-11-06' ? [delay] : <DailyAdjustment>[],
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(departureResultsProvider, (_, _) {});
      addTearDown(sub.close);
      final search = container.read(searchQueryProvider.notifier);
      search.from('B');
      search.to('C');
      search.journeyDate(today);
      container.read(debouncedSearchProvider.notifier).flush();
      await container.read(publishedServicesProvider.future);
      await container.read(dailyAdjustmentsProvider('2026-11-06').future);
      await Future<void>.delayed(Duration.zero);
      var results = container.read(departureResultsProvider).requireValue;
      expect(results.map((s) => s.id), ['second', 'first']);
      expect(results.last.expectedTime('B'), 515);
      expect(results.last.scheduledTime('B'), 495);
      search.journeyDate(DateTime(2026, 11, 7));
      container.read(debouncedSearchProvider.notifier).flush();
      await container.read(dailyAdjustmentsProvider('2026-11-07').future);
      await Future<void>.delayed(Duration.zero);
      results = container.read(departureResultsProvider).requireValue;
      expect(results.map((s) => s.id), ['first', 'second']);
      expect(results.first.expectedTime('B'), 495);
      expect(results.first.hasDailyAdjustment, isFalse);
    },
  );

  test(
    'failed daily reads expose a notice and retain the regular timetable',
    () async {
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          clockProvider.overrideWithValue(AsyncData(DateTime(2026, 11, 6))),
          publishedServicesProvider.overrideWith(
            (ref) => Stream.value([managed('one', 480)]),
          ),
          dailyAdjustmentsProvider.overrideWith(
            (ref, date) => Stream.error(StateError('offline')),
          ),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(departureResultsProvider, (_, _) {});
      final notice = container.listen(
        passengerDailyUpdatesUnavailableProvider,
        (_, _) {},
      );
      addTearDown(sub.close);
      addTearDown(notice.close);
      container.read(searchQueryProvider.notifier).from('A');
      container.read(searchQueryProvider.notifier).to('C');
      container.read(debouncedSearchProvider.notifier).flush();
      await container.read(publishedServicesProvider.future);
      await expectLater(
        container.read(dailyAdjustmentsProvider('2026-11-06').future),
        throwsStateError,
      );
      await Future<void>.delayed(Duration.zero);
      expect(container.read(passengerDailyUpdatesUnavailableProvider), isTrue);
      expect(
        container
            .read(departureResultsProvider)
            .requireValue
            .single
            .expectedTime('A'),
        480,
      );
    },
  );
}
