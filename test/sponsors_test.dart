import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kerala_bus_connect/features/sponsors/domain/entities/sponsored_ad.dart';
import 'package:kerala_bus_connect/features/sponsors/domain/repositories/sponsor_repository.dart';
import 'package:kerala_bus_connect/features/sponsors/presentation/providers/sponsor_providers.dart';
import 'support/fakes.dart';

class TestSponsorRepository implements SponsorRepository {
  final StreamController<List<SponsoredAd>> changes;
  int watches = 0;
  TestSponsorRepository(this.changes);
  @override
  Stream<List<SponsoredAd>> watch(String location) {
    watches++;
    return changes.stream;
  }
}

void main() {
  test(
    'sponsor listeners share a query, recover, and release idle resources',
    () async {
      var cancellations = 0;
      final stream = StreamController<List<SponsoredAd>>.broadcast(
        onCancel: () => cancellations++,
      );
      final repository = TestSponsorRepository(stream);
      final container = ProviderContainer(
        overrides: [
          sponsorRepositoryProvider.overrideWithValue(repository),
          sponsorLocationProvider.overrideWithValue('Aluva'),
          sponsorCacheDurationProvider.overrideWithValue(
            const Duration(milliseconds: 20),
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await stream.close();
      });
      final first = container.listen(sponsorsProvider, (_, _) {});
      final second = container.listen(liveSponsorsProvider('Aluva'), (_, _) {});
      expect(repository.watches, 1);
      stream.add([]);
      await container.read(liveSponsorsProvider('Aluva').future);
      expect(container.read(sponsorsProvider).requireValue.isDemo, isTrue);
      expect(
        container.read(sponsorsProvider).requireValue.records,
        hasLength(2),
      );
      stream.addError(StateError('permission-denied'));
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(container.read(sponsorsProvider).requireValue.isDemo, isTrue);
      expect(container.read(sponsorsProvider).requireValue.unavailable, isTrue);
      expect(repository.watches, 1);
      stream.add([sponsor('real')]);
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(sponsorsProvider).requireValue.records.single.id,
        'real',
      );
      expect(container.read(sponsorsProvider).requireValue.isDemo, isFalse);
      first.close();
      await container.pump();
      expect(cancellations, 0);
      second.close();
      await container.pump();
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await container.pump();
      expect(cancellations, 1);
    },
  );
}
