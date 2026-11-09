import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kerala_bus_connect/features/platform/domain/platform_repository.dart';
import 'package:kerala_bus_connect/features/platform/presentation/providers/platform_providers.dart';
import 'package:kerala_bus_connect/features/passenger/presentation/providers/paged_search_provider.dart';
import 'package:kerala_bus_connect/features/passenger/presentation/providers/search_providers.dart';
import 'package:kerala_bus_connect/features/passenger/data/public_page_cache.dart';
import 'package:kerala_bus_connect/features/places/domain/nearby_stops.dart';
import 'package:kerala_bus_connect/features/places/presentation/providers/nearby_providers.dart';

class MemoryPages extends PublicPageCache {
  Map<String, dynamic>? saved;
  MemoryPages() : super('test');
  @override
  Future<Map<String, dynamic>?> read(String query) async => saved;
  @override
  Future<void> write(String query, List<dynamic> records) async {}
  @override
  Future<void> invalidate() async {
    saved = null;
  }
}

class StubPlatform implements PlatformRepository {
  final Future<Map<String, dynamic>> Function(String, Map<String, Object?>)
  handler;
  int calls = 0;
  StubPlatform(this.handler);
  @override
  Future<Map<String, dynamic>> call(String name, Map<String, Object?> data) {
    calls++;
    return handler(name, data);
  }
}

class DeniedLocation implements LocationGateway {
  @override
  Future<StopPosition> locate({bool requestPermission = true}) async =>
      throw StateError('denied');
}

Map<String, dynamic> row(String id) => {
  'id': id,
  'published': true,
  'stops': ['A', 'B'],
  'stopIds': ['a', 'b'],
  'stopTimings': {'A': 600, 'B': 630},
  'departureMinutes': 600,
  'offDays': [],
  'serviceDate': '2026-11-09',
  'runningStatus': 'scheduled',
};
void main() {
  const query = (from: 'A', to: 'B', date: '2026-11-09', directory: false);
  test(
    'one first page is shared and repeated load-more requests deduplicate',
    () async {
      final pending = Completer<Map<String, dynamic>>();
      final remote = StubPlatform(
        (_, data) async => data['cursor'] == null
            ? {
                'records': [row('a')],
                'cursor': 'next',
              }
            : pending.future,
      );
      final container = ProviderContainer(
        overrides: [
          platformRepositoryProvider.overrideWithValue(remote),
          publicPageCacheProvider.overrideWithValue(MemoryPages()),
        ],
      );
      addTearDown(container.dispose);
      final provider = pagedDeparturesProvider(query);
      final sub = container.listen(provider, (_, _) {});
      addTearDown(sub.close);
      await Future.wait([
        container.read(provider.future),
        container.read(provider.future),
      ]);
      expect(remote.calls, 1);
      final notifier = container.read(provider.notifier);
      final next = notifier.next();
      final duplicate = notifier.next();
      pending.complete({
        'records': [row('a'), row('b')],
        'cursor': null,
      });
      await Future.wait([next, duplicate]);
      expect(remote.calls, 2);
      expect(container.read(provider).requireValue.records.map((s) => s.id), [
        'a',
        'b',
      ]);
    },
  );
  test('offline cached rows remain marked stale after refresh fails', () async {
    final cache = MemoryPages()
      ..saved = {
        'at': DateTime.now().toIso8601String(),
        'records': [row('saved')],
      };
    final container = ProviderContainer(
      overrides: [
        platformRepositoryProvider.overrideWithValue(
          StubPlatform((_, _) async => throw StateError('offline')),
        ),
        publicPageCacheProvider.overrideWithValue(cache),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(pagedDeparturesProvider(query), (_, _) {});
    addTearDown(sub.close);
    await container.read(pagedDeparturesProvider(query).future);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final page = container.read(pagedDeparturesProvider(query)).requireValue;
    expect(page.cached, true);
    expect(page.records.single.cachedAt, isNotNull);
    expect(page.error, isNotNull);
  });
  test(
    'permission denial does not call nearby API and manual search remains usable',
    () async {
      final remote = StubPlatform((_, _) async => {'stops': []});
      final container = ProviderContainer(
        overrides: [
          platformEnabledProvider.overrideWithValue(true),
          platformRepositoryProvider.overrideWithValue(remote),
          locationGatewayProvider.overrideWithValue(DeniedLocation()),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(nearbyStopsProvider, (_, _) {});
      addTearDown(sub.close);
      await expectLater(
        container.read(nearbyStopsProvider.future),
        throwsStateError,
      );
      expect(remote.calls, 0);
      container.read(searchQueryProvider.notifier).from('Manual stop');
      container.read(searchQueryProvider.notifier).autoOrigin('Nearest stop');
      expect(container.read(searchQueryProvider).from, 'Manual stop');
    },
  );
}
