import 'package:kerala_bus_connect/features/trips/presentation/widgets/bus_trip_dashboard.dart';
import 'package:kerala_bus_connect/features/timetables/presentation/providers/timetable_providers.dart';
import 'package:kerala_bus_connect/features/timetables/data/repositories/transit_repository_impl.dart';
import 'package:kerala_bus_connect/features/timetables/data/datasources/transit_remote_data_source.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kerala_bus_connect/core/theme/app_theme.dart';
import 'package:kerala_bus_connect/core/widgets/editor_sheet.dart';
import 'package:kerala_bus_connect/features/auth/domain/entities/auth_user.dart';
import 'package:kerala_bus_connect/features/auth/presentation/providers/auth_providers.dart';
import 'package:kerala_bus_connect/features/timetables/data/models/service_model.dart';
import 'package:kerala_bus_connect/features/trips/data/repositories/firebase_trip_repository.dart';
import 'package:kerala_bus_connect/features/trips/domain/entities/trip_plan.dart';
import 'package:kerala_bus_connect/features/trips/presentation/providers/trip_providers.dart';
import 'package:kerala_bus_connect/features/trips/presentation/widgets/trip_editor.dart';
import 'package:kerala_bus_connect/features/trips/presentation/widgets/daily_delay_editor.dart';
import 'support/fakes.dart';
import 'trip_schedule_test.dart' show example;

const bus = BusEntity(
  id: 'bus',
  ownerId: 'owner',
  businessId: 'business',
  name: 'Test bus',
);

Widget app(
  FirebaseTripRepository repository,
  Widget editor, {
  double scale = 1,
}) => ProviderScope(
  overrides: [
    authUserProvider.overrideWithValue(
      const AsyncData(AuthUser(id: 'owner', email: 'owner@test.com')),
    ),
    tripRepositoryProvider.overrideWithValue(repository),
  ],
  child: MaterialApp(
    theme: AppTheme.lightTheme,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: FilledButton(
            onPressed: () => openEditor(context, editor),
            child: const Text('Open editor'),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  late FakeFirebaseFirestore db;
  late FirebaseTripRepository repository;
  setUp(() async {
    db = FakeFirebaseFirestore();
    repository = FirebaseTripRepository(db);
    await db.collection('businesses').doc('business').set({
      'ownerId': 'owner',
      'name': business.name,
    });
    await db.collection('buses').doc('bus').set({
      'ownerId': 'owner',
      'businessId': 'business',
      'name': 'Test bus',
      'tripCount': 0,
    });
  });

  for (final width in [320.0, 390.0, 768.0]) {
    testWidgets(
      'trip editor works at width $width with large text and accessible moves',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          app(
            repository,
            TripEditor(business: business, bus: bus, initial: example()),
            scale: 1.4,
          ),
        );
        await tester.tap(find.text('Open editor'));
        await tester.pumpAndSettle();
        final move = find.byTooltip('Move down Kunnamkulam');
        await tester.ensureVisible(move);
        await tester.tap(move);
        await tester.pumpAndSettle();
        final undo = find.byTooltip('Move up Kunnamkulam');
        await tester.ensureVisible(undo);
        await tester.tap(undo);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Continue to timings'));
        await tester.tap(find.text('Continue to timings'));
        await tester.pumpAndSettle();
        expect(
          find.text(
            'Changing departure shifts every configured stop by the same amount.',
          ),
          findsOneWidget,
        );
        await tester.ensureVisible(find.byType(TextField));
        await tester.enterText(
          find.byType(TextField),
          'Updated passenger note',
        );
        await tester.pump();
        await tester.ensureVisible(find.text('Review trip'));
        await tester.tap(find.text('Review trip'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Save trip'));
        await tester.tap(find.text('Save trip'));
        await tester.pumpAndSettle();
        expect(find.text('Open editor'), findsOneWidget);
        final saved = (await db.collection('services').get()).docs;
        expect(saved, hasLength(1));
        expect(saved.single.data()['offTimingsNote'], 'Updated passenger note');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'saved delay reopens as a value and can be corrected without accumulating',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final id = await repository.saveTrip('owner', business, bus, example());
      final trip = TripPlan.fromService(
        ServiceModel.fromSnapshot(
          await db.collection('services').doc(id).get(),
        ),
      );
      final initial = DailyAdjustment(
        tripId: id,
        serviceDate: '2026-11-06',
        scheduleRevision: trip.revision,
        delays: {'a': 5, 'd': 10},
      );
      await repository.saveAdjustment('owner', bus, trip, initial);
      await tester.pumpWidget(
        app(
          repository,
          DailyDelayEditor(
            bus: bus,
            trip: trip,
            date: '2026-11-06',
            initial: initial,
          ),
        ),
      );
      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();
      final edit = find.text('Edit delay (+10 min)');
      await tester.ensureVisible(edit);
      await tester.tap(edit);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '3');
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(find.text('Expected: 9:08 AM'), findsOneWidget);
      await tester.ensureVisible(find.text('Save daily adjustments'));
      await tester.tap(find.text('Save daily adjustments'));
      await tester.pumpAndSettle();
      final daily =
          (await repository.watchAdjustments('2026-11-06').first).single;
      expect(daily.delays, {'a': 5, 'd': 3});
      expect(trip.expectedTimes(daily.delays).last, 548);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('bus selector shows only the chosen bus trips', (tester) async {
    await repository.saveTrip('owner', business, bus, example());
    await repository.saveBus('owner', business, 'Second bus');
    final second = (await repository.watchBuses('owner', business.id).first)
        .firstWhere((b) => b.id != bus.id);
    await repository.saveTrip(
      'owner',
      business,
      second,
      example().returnTrip(600),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authUserProvider.overrideWithValue(
            const AsyncData(AuthUser(id: 'owner', email: 'owner@test.com')),
          ),
          tripRepositoryProvider.overrideWithValue(repository),
          transitRepositoryProvider.overrideWithValue(
            TransitRepositoryImpl(TransitRemoteDataSourceImpl(db)),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: CustomScrollView(
              slivers: [BusTripDashboard(business: business)],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(BusTripDashboard)),
    );
    container.read(selectedBusProvider(business.id).notifier).select(bus.id);
    await tester.pumpAndSettle();
    expect(find.text('Kunnamkulam → Wadakkanchery'), findsOneWidget);
    expect(find.text('Wadakkanchery → Kunnamkulam'), findsNothing);
    container.read(selectedBusProvider(business.id).notifier).select(second.id);
    await tester.pumpAndSettle();
    expect(find.text('Wadakkanchery → Kunnamkulam'), findsOneWidget);
    expect(find.text('Kunnamkulam → Wadakkanchery'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('12-hour labels identify midnight and next-day arrivals', () {
    expect(tripTimeLabel(0), '12:00 AM');
    expect(tripTimeLabel(720), '12:00 PM');
    expect(tripTimeLabel(1445), '12:05 AM · Next day');
  });
}
