import 'dart:async';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kerala_bus_connect/core/providers/clock_provider.dart';
import 'package:kerala_bus_connect/features/auth/domain/entities/auth_user.dart';
import 'package:kerala_bus_connect/features/auth/presentation/providers/auth_providers.dart';
import 'package:kerala_bus_connect/features/owner/presentation/providers/owner_providers.dart';
import 'package:kerala_bus_connect/features/passenger/presentation/providers/search_providers.dart';
import 'package:kerala_bus_connect/features/routes/presentation/providers/route_query_provider.dart';
import 'package:kerala_bus_connect/features/timetables/domain/entities/service_entity.dart';
import 'package:kerala_bus_connect/features/timetables/presentation/providers/timetable_providers.dart';
import 'support/fakes.dart';

void main() {
  test('search debounces rapid input and cancels pending work on disposal', () {
    fakeAsync((async) {
      final container = ProviderContainer();
      final results = <String>[];
      final sub = container.listen(
        debouncedSearchProvider,
        (_, value) => results.add(value.from),
      );
      final controller = container.read(searchQueryProvider.notifier);
      controller.from('A');
      async.elapse(const Duration(milliseconds: 100));
      controller.from('Kalamassery');
      async.elapse(const Duration(milliseconds: 199));
      expect(results, isEmpty);
      async.elapse(const Duration(milliseconds: 1));
      expect(results, ['Kalamassery']);
      controller.from('Pending');
      sub.close();
      container.dispose();
      async.elapse(const Duration(seconds: 1));
      expect(results, ['Kalamassery']);
    });
  });

  test(
    'search and directory share one subscription and release it when idle',
    () async {
      final repository = FakeTransitRepository();
      final stream = StreamController<List<ServiceEntity>>.broadcast(
        onCancel: () => repository.cancellations++,
      );
      repository.publishedOverride = stream.stream;
      final container = ProviderContainer(
        overrides: [
          transitRepositoryProvider.overrideWithValue(repository),
          catalogCacheDurationProvider.overrideWithValue(Duration.zero),
          clockProvider.overrideWith(
            (ref) => Stream.value(DateTime(2026, 11, 5, 8)),
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await stream.close();
      });
      final search = container.listen(departureResultsProvider, (_, value) {});
      final directory = container.listen(
        directoryResultsProvider,
        (_, value) {},
      );
      stream.add([service('one')]);
      await container.read(publishedServicesProvider.future);
      expect(repository.publishedRequests, 1);
      expect(
        container.read(departureResultsProvider).requireValue,
        hasLength(1),
      );
      expect(
        container.read(directoryResultsProvider).requireValue,
        hasLength(1),
      );
      search.close();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(repository.cancellations, 0);
      directory.close();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(repository.cancellations, 1);
    },
  );

  test('a failed catalogue exposes the error and can be retried', () async {
    final repository = FakeTransitRepository()
      ..publishedOverride = Stream.error(StateError('offline'));
    final container = ProviderContainer(
      retry: (_, error) => null,
      overrides: [
        transitRepositoryProvider.overrideWithValue(repository),
        catalogCacheDurationProvider.overrideWithValue(Duration.zero),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(publishedServicesProvider, (_, value) {});
    addTearDown(sub.close);
    await expectLater(
      container.read(publishedServicesProvider.future),
      throwsStateError,
    );
    expect(container.read(publishedServicesProvider).hasError, isTrue);
    repository.publishedOverride = Stream.value([service('retried')]);
    container.invalidate(publishedServicesProvider);
    expect(
      (await container.read(publishedServicesProvider.future)).single.id,
      'retried',
    );
    expect(repository.publishedRequests, 2);
  });

  test(
    'owner queries and selected business reset when the user changes',
    () async {
      final auth = FakeAuthRepository(
        user: const AuthUser(id: 'owner', email: 'one@example.com'),
      );
      final repository = FakeTransitRepository();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          transitRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await auth.changes.close();
      });
      final businesses = container.listen(
        ownerBusinessesProvider,
        (_, value) {},
      );
      final selected = container.listen(
        selectedBusinessIdProvider,
        (_, value) {},
      );
      addTearDown(businesses.close);
      addTearDown(selected.close);
      await container.read(authUserProvider.future);
      await container.read(ownerBusinessesProvider.future);
      container
          .read(selectedBusinessIdProvider.notifier)
          .select('private-business');
      await auth.signOut();
      await Future<void>.delayed(Duration.zero);
      expect(container.read(ownerIdProvider), isNull);
      expect(container.read(selectedBusinessIdProvider), isNull);
      expect(await container.read(ownerBusinessesProvider.future), isEmpty);
      auth.user = const AuthUser(id: 'second-owner', email: 'two@example.com');
      auth.changes.add(auth.user);
      await Future<void>.delayed(Duration.zero);
      final list = await container.read(ownerBusinessesProvider.future);
      expect(repository.lastBusinessOwner, 'second-owner');
      expect(list.single.ownerId, 'second-owner');
    },
  );

  test(
    'service drafts are isolated and discarded after the editor closes',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final args = (route: route, service: null as ServiceEntity?);
      final sub = container.listen(serviceDraftProvider(args), (_, value) {});
      final controller = container.read(serviceDraftProvider(args).notifier);
      controller.departure(600);
      controller.toggleDay('Monday');
      expect(container.read(serviceDraftProvider(args)).timings['Kaloor'], 630);
      sub.close();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final reopened = container.listen(
        serviceDraftProvider(args),
        (_, value) {},
      );
      addTearDown(reopened.close);
      expect(container.read(serviceDraftProvider(args)).departure, 480);
      expect(container.read(serviceDraftProvider(args)).offDays, isEmpty);
    },
  );

  test('owner commands reject signed-out sessions without throwing or writing', () async {
    final auth = FakeAuthRepository();
    final repository = FakeTransitRepository();
    final container = ProviderContainer(overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      transitRepositoryProvider.overrideWithValue(repository),
    ]);
    addTearDown(() async { container.dispose(); await auth.changes.close(); });
    final sub = container.listen(ownerActionsProvider, (_, value) {});
    addTearDown(sub.close);
    await container.read(authUserProvider.future);
    final saved = await container.read(ownerActionsProvider.notifier).saveBusiness('Example');
    expect(saved, isFalse);
    expect(repository.writes, 0);
    expect(container.read(ownerActionsProvider).hasError, isTrue);
  });
}
