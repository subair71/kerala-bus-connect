import 'package:kerala_bus_connect/features/sponsors/domain/entities/sponsored_ad.dart';
import 'package:kerala_bus_connect/core/theme/app_theme.dart';
import 'package:kerala_bus_connect/features/sponsors/presentation/providers/sponsor_providers.dart';
import 'package:kerala_bus_connect/features/tracking/presentation/providers/tracking_providers.dart';
import 'package:kerala_bus_connect/features/crew/presentation/providers/crew_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kerala_bus_connect/app/app_shell.dart';
import 'package:kerala_bus_connect/core/providers/clock_provider.dart';
import 'package:kerala_bus_connect/features/auth/domain/entities/auth_user.dart';
import 'package:kerala_bus_connect/features/auth/presentation/providers/auth_providers.dart';
import 'package:kerala_bus_connect/features/owner/presentation/pages/owner_page.dart';
import 'package:kerala_bus_connect/features/passenger/presentation/pages/passenger_page.dart';
import 'package:kerala_bus_connect/features/passenger/presentation/widgets/search_panel.dart';
import 'package:kerala_bus_connect/features/timetables/presentation/providers/timetable_providers.dart';
import 'package:kerala_bus_connect/features/timetables/presentation/widgets/service_card.dart';
import 'support/fakes.dart';

Widget harness(
  Widget child,
  FakeTransitRepository repository,
  FakeAuthRepository auth, {
  Stream<List<SponsoredAd>>? sponsorStream,
}) => ProviderScope(
  overrides: [
    liveSponsorsProvider.overrideWith(
      (ref, location) => sponsorStream ?? Stream.value([]),
    ),
    liveTrackingProvider.overrideWith((ref) => Stream.value([])),
    liveCrewProvider.overrideWith((ref) => Stream.value([])),
    transitRepositoryProvider.overrideWithValue(repository),
    authRepositoryProvider.overrideWithValue(auth),
    catalogCacheDurationProvider.overrideWithValue(Duration.zero),
    clockProvider.overrideWith((ref) => Stream.value(DateTime(2026, 11, 5, 8))),
  ],
  child: MaterialApp(theme: AppTheme.lightTheme, home: child),
);

void main() {
  testWidgets(
    'typing preserves the controller and cursor; swapping updates both fields',
    (tester) async {
      final auth = FakeAuthRepository();
      addTearDown(auth.changes.close);
      await tester.pumpWidget(
        harness(
          const Scaffold(body: SearchPanel()),
          FakeTransitRepository(),
          auth,
        ),
      );
      final from = find.byKey(const ValueKey('search-from'));
      final controller = tester.widget<TextField>(from).controller!;
      await tester.enterText(from, 'Kalamassery');
      await tester.pump();
      expect(
        identical(controller, tester.widget<TextField>(from).controller),
        isTrue,
      );
      expect(controller.selection.baseOffset, 'Kalamassery'.length);
      await tester.tap(find.byKey(const ValueKey('swap-stops')));
      await tester.pump();
      expect(controller.text, 'Kaloor');
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('search-to')))
            .controller!
            .text,
        'Kalamassery',
      );
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets('200 timetables render lazily without mobile overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = FakeAuthRepository();
    addTearDown(auth.changes.close);
    final repository = FakeTransitRepository(
      services: [
        for (var i = 0; i < 200; i++)
          service('$i', bus: 'Bus $i', departure: 480 + i),
      ],
    );
    await tester.pumpWidget(
      harness(const Scaffold(body: PassengerPage()), repository, auth),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ServiceCard).evaluate().length, lessThan(12));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -550));
    await tester.pumpAndSettle();
    expect(find.byType(ServiceCard), findsWidgets);
    expect(find.byType(ServiceCard).evaluate().length, lessThan(12));
    expect(tester.takeException(), isNull);
    expect(repository.publishedRequests, 1);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('all feature tabs open; demo features are identified', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    addTearDown(auth.changes.close);
    await tester.pumpWidget(
      harness(
        const AppShell(),
        FakeTransitRepository(services: [service('one')]),
        auth,
      ),
    );
    await tester.pumpAndSettle();
    for (final label in ['Routes', 'Owner', 'Tracking', 'Crew', 'Find bus']) {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (label == 'Owner') expect(find.text('Owner sign in'), findsOneWidget);
      if (label == 'Tracking' || label == 'Crew') {
        expect(find.textContaining('Demo'), findsWidgets);
      }
    }
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('owner sign-in validates fields before authentication', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    addTearDown(auth.changes.close);
    await tester.pumpWidget(
      harness(const Scaffold(body: OwnerPage()), FakeTransitRepository(), auth),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(auth.signIns, 0);
    await tester.enterText(
      find.byKey(const ValueKey('auth-email')),
      'test@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-password')),
      'secret123',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(auth.signIns, 1);
    expect(find.text('Owner portal'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('owner creates a business through a Riverpod save action', (
    tester,
  ) async {
    final auth = FakeAuthRepository(
      user: const AuthUser(id: 'owner', email: 'test@example.com'),
    );
    addTearDown(auth.changes.close);
    final repository = FakeTransitRepository();
    await tester.pumpWidget(
      harness(const Scaffold(body: OwnerPage()), repository, auth),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add business'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('business-name')),
      'Kerala operator',
    );
    await tester.tap(find.text('Save business'));
    await tester.pumpAndSettle();
    expect(repository.writes, 1);
    expect(find.byKey(const ValueKey('business-name')), findsNothing);
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
