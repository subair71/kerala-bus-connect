import 'dart:convert';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kerala_bus_connect/app/app_shell.dart';
import 'package:kerala_bus_connect/core/providers/clock_provider.dart';
import 'package:kerala_bus_connect/core/providers/firebase_providers.dart';
import 'package:kerala_bus_connect/core/theme/app_theme.dart';
import 'package:kerala_bus_connect/features/auth/presentation/providers/auth_providers.dart';
import 'package:kerala_bus_connect/features/journeys/domain/journey_filters.dart';
import 'package:kerala_bus_connect/features/journeys/domain/journey_repository.dart';
import 'package:kerala_bus_connect/features/journeys/presentation/providers/journey_providers.dart';
import 'package:kerala_bus_connect/features/timetables/data/models/service_model.dart';
import 'package:kerala_bus_connect/features/timetables/domain/entities/service_entity.dart';
import 'package:kerala_bus_connect/features/tracking/domain/entities/tracking_preview.dart';
import 'package:kerala_bus_connect/features/tracking/presentation/providers/tracking_providers.dart';
import 'package:kerala_bus_connect/features/places/domain/nearby_stops.dart';
import 'package:kerala_bus_connect/features/places/presentation/providers/nearby_providers.dart';
import 'package:kerala_bus_connect/features/trips/presentation/providers/trip_providers.dart';
import 'fakes.dart';

class _DeviceBook implements JourneyRepository {
  final List<SavedJourney> items = [];
  @override
  Future<List<SavedJourney>> readBookmarks() async => List.of(items);
  @override
  Future<void> writeBookmarks(List<SavedJourney> value) async {
    items
      ..clear()
      ..addAll(value);
  }

  @override
  Future<SampleCatalogue> samples() async =>
      (records: <ServiceEntity>[], cloud: false);
  @override
  Future<ServiceEntity?> timetable(
    String id,
    String date, {
    required bool regular,
  }) async => null;
}

class _NearbyFixture extends NearbyStops {
  @override
  Future<NearbyState> build() async => const NearbyState([
    NearbyStop(id: 'aluva', name: 'Aluva', distanceKm: .25),
    NearbyStop(id: 'market', name: 'Market Road', distanceKm: .48),
    NearbyStop(id: 'rail', name: 'Railway Station', distanceKm: .75),
  ]);
}

void referenceFlows({bool screenshots = false}) {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (screenshots)
    setUpAll(() async {
      for (final (family, path) in [
        ('Plus Jakarta Sans', 'assets/fonts/PlusJakartaSans[wght].ttf'),
        ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
      ]) {
        final loader = FontLoader(family)..addFont(rootBundle.load(path));
        await loader.load();
      }
    });
  testWidgets('all 25 PDF screens through passenger and operator navigation', (
    t,
  ) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(390, 844);
    addTearDown(t.view.reset);
    final db = FakeFirebaseFirestore(),
        auth = FakeAuthRepository(),
        book = _DeviceBook();
    addTearDown(auth.changes.close);
    const date = '2026-11-27';
    final rows =
        jsonDecode(await rootBundle.loadString('assets/samples/services.json'))
            as List;
    await db.collection('businesses').doc('operator').set({
      'ownerId': 'owner',
      'name': 'Example operator',
    });
    await db.collection('buses').doc('bus').set({
      'ownerId': 'owner',
      'businessId': 'operator',
      'name': 'KT 01',
      'tripCount': 1,
    });
    final services = <ServiceEntity>[];
    for (final source in rows) {
      final raw = Map<String, dynamic>.from(source as Map);
      final id = (raw.remove('id') as String).substring(5);
      final stops = (raw['stops'] as List).cast<String>();
      raw.addAll({
        'ownerId': 'owner',
        'businessId': 'operator',
        'busId': id == 'kt01' ? 'bus' : id,
        'stopIds': [for (var i = 0; i < stops.length; i++) 's$i'],
        'scheduleRevision': 'rev1',
      });
      await db.collection('services').doc(id).set(raw);
      services.add(ServiceModel.fromMap(id, raw));
    }
    final dateAdjustment = services.first.withExpected({
      for (final e in services.first.stopTimings.entries) e.key: e.value + 5,
    }, date);
    var unavailable = false, empty = false;
    final container = ProviderContainer(
      overrides: [
        firestoreProvider.overrideWithValue(db),
        authRepositoryProvider.overrideWithValue(auth),
        clockProvider.overrideWithValue(AsyncData(DateTime(2026, 11, 27, 9))),
        operationDateProvider.overrideWithBuild(
          (ref, _) => DateTime(2026, 11, 27),
        ),
        journeyRepositoryProvider.overrideWithValue(book),
        nearbyStopsProvider.overrideWith(_NearbyFixture.new),
        liveTrackingProvider.overrideWith(
          (ref) =>
              Stream.value([TrackingPreview('KT 01', services.first.stops, 1)]),
        ),
        journeyFeedProvider.overrideWith((ref, q) {
          final entries = [
            for (final r in services)
              if (!empty &&
                  (q.directory
                      ? r.routeName.toLowerCase().contains(q.from.toLowerCase())
                      : r.stops.contains(q.from) &&
                            (q.to.isEmpty ||
                                r.stops.indexOf(q.to) >
                                    r.stops.indexOf(q.from))))
                (!q.directory && !unavailable && r.id == 'kt01'
                    ? dateAdjustment
                    : r),
          ];
          return AsyncData((
            rows: entries,
            sample: false,
            stale: false,
            updatesMissing: unavailable,
            more: false,
          ));
        }),
      ],
    );
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: RepaintBoundary(
          key: const ValueKey('screen-capture'),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            home: const AppShell(),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    container
        .read(journeyFiltersProvider.notifier)
        .apply(const JourneyFilters(after: 540));
    await t.runAsync(() async {
      final c = t.element(find.byType(AppShell));
      await Future.wait([
        precacheImage(const AssetImage('assets/images/findmybus-logo.jpg'), c),
        precacheImage(const AssetImage('assets/images/guide-map.png'), c),
      ]);
    });
    await t.pumpAndSettle();
    final seen = <int>{};
    Future<void> screen(int i, String heading) async {
      expect(find.text(heading), findsAtLeastNWidgets(1), reason: 'Screen $i');
      expect(t.takeException(), isNull, reason: 'Layout on screen $i');
      seen.add(i);
      if (screenshots)
        await expectLater(
          find.byKey(const ValueKey('screen-capture')),
          matchesGoldenFile('screenshots/${i.toString().padLeft(2, '0')}.png'),
        );
    }

    Future<void> click(String label, {bool last = false}) async {
      final f = last ? find.text(label).last : find.text(label).first;
      await t.ensureVisible(f);
      await t.tap(f);
      await t.pumpAndSettle();
    }

    Future<void> back() async {
      await t.tap(find.byTooltip('Back'));
      await t.pumpAndSettle();
    }

    await screen(1, 'Find a bus');
    await click('Going to');
    await screen(2, 'Where to?');
    await back();
    await click('Stops near me');
    await screen(3, 'Nearby stops');
    await back();
    await click('Fri, 27 Nov');
    await screen(4, 'When are you leaving?');
    await back();
    await click('Search buses');
    await screen(5, 'Bus results');
    await click('Filters');
    await screen(6, 'Filter buses');
    await click('Owner updated');
    await click('Show 1 bus');
    await click('KT 01 · Kaloor');
    await screen(7, 'Trip details');
    await click('Save trip');
    await click('Reminder');
    await screen(14, 'Remind me');
    await back();
    await click('View all 5 stops');
    await screen(8, 'Stop sequence');
    await click('Route position preview');
    await screen(12, 'Kalamassery');
    await click('Routes', last: true);
    await screen(9, 'Published routes');
    await click('Aluva → Kaloor');
    await screen(10, 'Route timetable');
    await click('Save route');
    await click('Departures', last: true);
    await screen(11, 'Upcoming buses');
    await click('Save this stop');
    await click('Saved', last: true);
    await screen(13, 'My journeys');
    expect(
      book.items.map((e) => e.kind),
      containsAll(['route', 'stop', 'trip']),
    );
    await click('More', last: true);
    await screen(16, 'Passenger tools');
    await click('Service updates');
    await screen(15, 'For this journey');
    await click('Find bus', last: true);
    empty = true;
    container.invalidate(journeyFeedProvider);
    await click('Search buses');
    await screen(17, 'No matching buses');
    await back();
    empty = false;
    unavailable = true;
    container.invalidate(journeyFeedProvider);
    container
        .read(journeyFiltersProvider.notifier)
        .apply(const JourneyFilters());
    await click('Search buses');
    await screen(18, 'Timetable status');
    await click('More', last: true);
    await click('Crew duty roster');
    await screen(25, 'Crew duty roster');
    await back();
    await click('Owner sign in');
    await screen(19, 'Owner sign in');
    await t.enterText(find.byType(TextField).at(0), 'owner@example.com');
    await t.enterText(find.byType(TextField).at(1), 'correct-password');
    await click('Sign in');
    await screen(20, 'Buses & trips');
    await click('Edit regular trip');
    await screen(21, 'Route & stops');
    await click('Continue to timings');
    await screen(22, 'Regular timings');
    await click('Review trip');
    await screen(23, 'Publish timetable');
    await click('Publish timetable');
    await click('Daily update');
    await screen(24, 'Daily update');
    await click('Additional delay');
    await t.enterText(find.byType(TextField).last, '5');
    await click('Save');
    await click('Save daily update');
    expect(find.text('Buses & trips'), findsOneWidget);
    final adjustments = await db.collection('trip_adjustments').get();
    expect(adjustments.docs.single.data()['serviceDate'], date);
    expect(seen.length, 25);
    await t.pumpWidget(const SizedBox());
    container.dispose();
    await t.pump();
  }, timeout: const Timeout(Duration(minutes: 2)));
}
