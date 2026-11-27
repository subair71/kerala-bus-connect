import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kerala_bus_connect/core/providers/firebase_providers.dart';
import 'package:kerala_bus_connect/features/journeys/domain/journey_filters.dart';
import 'package:kerala_bus_connect/features/journeys/presentation/pages/discovery_pages.dart';
import 'package:kerala_bus_connect/features/journeys/presentation/pages/trip_pages.dart';
import 'package:kerala_bus_connect/features/journeys/presentation/providers/journey_providers.dart';
import 'package:kerala_bus_connect/features/journeys/presentation/widgets/journey_controls.dart';
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
  testWidgets(
    'saved sample opens its Firestore timetable from a fresh session',
    (tester) async {
      final db = FakeFirebaseFirestore();
      await db.collection('sample_services').doc('demo:kt01').set({
        'sample': true,
        'busName': 'KT 01',
        'routeName': 'Aluva to Kaloor',
        'stops': ['Aluva', 'Kaloor'],
        'departureMinutes': 560,
        'stopTimings': {'Aluva': 560, 'Kaloor': 610},
        'offDays': [],
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [firestoreProvider.overrideWithValue(db)],
          child: const MaterialApp(
            home: Scaffold(
              body: SavedServicePage(
                SavedJourney(
                  'trip',
                  'Example',
                  from: 'Aluva',
                  to: 'Kaloor',
                  serviceId: 'demo:kt01',
                  sampleCatalogue: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('KT 01'));
      await tester.pumpAndSettle();
      expect(find.byType(TripPage), findsOneWidget);
      expect(find.text('09:20'), findsOneWidget);
    },
  );
  testWidgets(
    'journey calendar applies the local selection only after confirmation',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) => Scaffold(
                body: TextButton(
                  onPressed: () => openJourneyTime(context, ref),
                  child: const Text('Choose date'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Choose date'));
      await tester.pumpAndSettle();
      expect(find.byType(CalendarDatePicker), findsOneWidget);
      expect(find.text('Any time'), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -450));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Use '));
      await tester.pumpAndSettle();
      expect(find.text('Choose date'), findsOneWidget);
    },
  );
}
