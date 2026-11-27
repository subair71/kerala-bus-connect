import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kerala_bus_connect/core/providers/firebase_providers.dart';
import 'package:kerala_bus_connect/features/journeys/domain/journey_filters.dart';
import 'package:kerala_bus_connect/features/journeys/presentation/providers/journey_providers.dart';
import 'support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('a late service is filtered at the selected stop and expected time', () {
    final changed = service(
      'a',
    ).withExpected({'Kalamassery': 505}, '2026-11-27');
    const filter = JourneyFilters(after: 500, status: TimetableStatus.updated);
    expect(filter.accepts(changed, 'Aluva'), isFalse);
    expect(filter.accepts(changed, 'Kalamassery'), isTrue);
    expect(filter.accepts(service('b'), 'Kalamassery'), isFalse);
  });
  test('an overnight reminder resolves to the next calendar day in Kerala', () {
    expect(
      boardingUtc(DateTime(2026, 11, 27), 1470),
      DateTime.utc(2026, 11, 27, 19),
    );
    expect(clock24(1470), '00:30 +1d');
  });
  test('existing saved items and explicit sample items keep their origin', () {
    final old = SavedJourney.fromJson({
      'kind': 'trip',
      'name': 'My trip',
      'from': 'A',
      'to': 'B',
      'service': '42',
    });
    expect(old.sampleCatalogue, isFalse);
    const sample = SavedJourney(
      'trip',
      'My sample trip',
      serviceId: 'demo:kt01',
      sampleCatalogue: true,
    );
    expect(SavedJourney.fromJson(sample.toJson()).sampleCatalogue, isTrue);
  });
  test(
    'the empty sample collection falls back to five separate example services',
    () async {
      final ref = ProviderContainer(
        overrides: [
          firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
        ],
      );
      addTearDown(ref.dispose);
      final list = await ref.read(sampleCatalogueProvider.future);
      expect(list.cloud, isFalse);
      expect(list.records.length, 5);
      expect(list.records.map((x) => x.id).toSet().length, 5);
    },
  );
}
