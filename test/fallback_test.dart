import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kerala_bus_connect/core/errors/app_failure.dart';
import 'package:kerala_bus_connect/core/providers/sample_fallback.dart';
import 'package:kerala_bus_connect/features/owner/domain/usecases/manage_transit.dart';
import 'package:kerala_bus_connect/features/passenger/presentation/providers/search_providers.dart';
import 'package:kerala_bus_connect/features/sponsors/domain/entities/sponsored_ad.dart';
import 'package:kerala_bus_connect/features/sponsors/data/fixtures/sponsor_samples.dart';
import 'package:kerala_bus_connect/features/timetables/data/fixtures/transit_samples.dart';
import 'package:kerala_bus_connect/features/timetables/data/models/service_model.dart';
import 'package:kerala_bus_connect/features/timetables/domain/entities/service_entity.dart';
import 'package:kerala_bus_connect/features/timetables/presentation/providers/timetable_providers.dart';
import 'support/fakes.dart';

void main() {
  test('loading, empty and failed sources remain distinguishable', () {
    expect(sampleFallback<int>(const AsyncLoading(), [1]).isLoading, isTrue);
    final empty = sampleFallback<int>(const AsyncData([]), [1]).requireValue;
    expect(empty.isDemo, isTrue);
    expect(empty.unavailable, isFalse);
    final failed = sampleFallback<int>(
      AsyncError(StateError('offline'), StackTrace.current),
      [1],
    ).requireValue;
    expect(failed.unavailable, isTrue);
    expect(failed.records, [1]);
    final live = sampleFallback<int>(const AsyncData([0]), [1]).requireValue;
    expect(live.records, [0]);
    expect(live.isDemo, isFalse);
  });

  test(
    'a subscription replaces empty and failed samples with live records',
    () async {
      final stream = StreamController<List<ServiceEntity>>();
      final repository = FakeTransitRepository()
        ..publishedOverride = stream.stream;
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          transitRepositoryProvider.overrideWithValue(repository),
          catalogCacheDurationProvider.overrideWithValue(Duration.zero),
        ],
      );
      final sub = container.listen(serviceCatalogProvider, (_, _) {});
      addTearDown(() async {
        sub.close();
        container.dispose();
        await stream.close();
      });
      stream.add([]);
      await container.read(publishedServicesProvider.future);
      expect(
        container.read(serviceCatalogProvider).requireValue.isDemo,
        isTrue,
      );
      stream.addError(StateError('offline'));
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(serviceCatalogProvider).requireValue.unavailable,
        isTrue,
      );
      stream.add([service('real')]);
      await Future<void>.delayed(Duration.zero);
      final live = container.read(serviceCatalogProvider).requireValue;
      expect(live.isDemo, isFalse);
      expect(live.records.map((s) => s.id), ['real']);
    },
  );

  test(
    'a no-match search in a real catalogue does not add fictional buses',
    () async {
      final container = ProviderContainer(
        overrides: [
          transitRepositoryProvider.overrideWithValue(
            FakeTransitRepository(services: [service('real')]),
          ),
          catalogCacheDurationProvider.overrideWithValue(Duration.zero),
          searchDebounceDurationProvider.overrideWithValue(Duration.zero),
        ],
      );
      final sub = container.listen(departureResultsProvider, (_, _) {});
      addTearDown(() {
        sub.close();
        container.dispose();
      });
      await container.read(publishedServicesProvider.future);
      container.read(searchQueryProvider.notifier).from('Thrissur');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(container.read(departureResultsProvider).requireValue, isEmpty);
      expect(
        container.read(serviceCatalogProvider).requireValue.isDemo,
        isFalse,
      );
    },
  );

  test(
    'missing schedule fields never become midnight or invented stop times',
    () {
      final missing = ServiceModel.fromMap('real', {
        'stops': ['Aluva', 'Kaloor'],
      });
      expect(missing.departureMinutes, -1);
    expect(missing.operatingDaysKnown, isFalse);
      expect(missing.scheduledTime('Aluva'), isNull);
      expect(missing.scheduledTime('Kaloor'), isNull);
      expect(missing.busName, 'Bus name unavailable');
      final valid = ServiceModel.fromMap('real', {
        'departureMinutes': 0,
        'published': false,
        'stops': ['Aluva', 'Kaloor'],
        'stopTimings': {'Aluva': 0, 'Kaloor': 'bad', 'Other': false},
      });
      expect(valid.departureMinutes, 0);
      expect(valid.published, isFalse);
      expect(valid.scheduledTime('Aluva'), 0);
      expect(valid.scheduledTime('Kaloor'), isNull);
      expect(valid.stopTimings, {'Aluva': 0});
    },
  );

  test('all sample mutation paths fail before repository writes', () async {
    final repository = FakeTransitRepository();
    final manage = ManageTransit(repository);
    final demoBusiness = TransitSamples.businesses.first;
    final demoRoute = TransitSamples.routes.first;
    await expectLater(
      manage.saveBusiness('owner', 'Name', id: demoBusiness.id),
      throwsA(isA<AppFailure>()),
    );
    await expectLater(
      manage.saveRoute(
        ownerId: 'owner',
        business: demoBusiness,
        name: 'Route',
        from: 'A',
        to: 'B',
        intermediateStops: '',
        returnRoute: false,
      ),
      throwsA(isA<AppFailure>()),
    );
    await expectLater(
      manage.generateReturn(demoRoute, 'owner'),
      throwsA(isA<AppFailure>()),
    );
    await expectLater(
      manage.deleteRoute(demoRoute.id, []),
      throwsA(isA<AppFailure>()),
    );
    await expectLater(
      manage.deleteService(TransitSamples.services.first.id),
      throwsA(isA<AppFailure>()),
    );
    await expectLater(
      manage.saveService(
        ownerId: 'owner',
        business: business,
        route: route,
        busName: 'Bus',
        departure: 480,
        timings: {'Kalamassery': 495, 'Kaloor': 510},
        offDays: {},
        note: '',
        existing: [],
        serviceId: 'demo:service-x',
      ),
      throwsA(isA<AppFailure>()),
    );
    expect(repository.writes, 0);
    expect(repository.routeWrites, isEmpty);
  });

  test('real schedule publication requires each intermediate time', () async {
    final repository = FakeTransitRepository();
    await expectLater(
      ManageTransit(repository).saveService(
        ownerId: 'owner',
        business: business,
        route: route,
        busName: 'Bus',
        departure: 480,
        timings: {},
        offDays: {},
        note: '',
        existing: [],
      ),
      throwsA(isA<AppFailure>()),
    );
    expect(repository.writes, 0);
  });

  test(
    'sponsors follow normalized boarding location with stable sample IDs',
    () {
      expect(sponsorLocation(' Thrissur Round '), 'Thrissur');
      expect(sponsorLocation('Aluva Metro'), 'Aluva');
      expect(
        sponsorSamples('Aluva').map((a) => a.id),
        sponsorSamples('Aluva').map((a) => a.id),
      );
      expect(
        sponsorSamples('Thrissur').first.id,
        isNot(sponsorSamples('Aluva').first.id),
      );
    },
  );
}
