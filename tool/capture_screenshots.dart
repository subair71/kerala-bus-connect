import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kerala_bus_connect/features/places/domain/services/stop_labels.dart';
import 'package:kerala_bus_connect/features/places/presentation/providers/places_providers.dart';
import '../test/places_widget_test.dart' show WidgetPlaces;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerala_bus_connect/app/app_shell.dart';
import 'package:kerala_bus_connect/features/sponsors/presentation/widgets/sponsored_carousel.dart';
import 'package:kerala_bus_connect/core/widgets/editor_sheet.dart';
import 'package:kerala_bus_connect/features/auth/domain/entities/auth_user.dart';
import 'package:kerala_bus_connect/features/owner/presentation/pages/owner_page.dart';
import 'package:kerala_bus_connect/features/owner/presentation/widgets/business_editor.dart';
import 'package:kerala_bus_connect/features/owner/presentation/widgets/route_editor.dart';
import 'package:kerala_bus_connect/features/owner/presentation/widgets/service_editor.dart';
import 'package:kerala_bus_connect/features/timetables/presentation/widgets/stop_timings_sheet.dart';
import '../test/support/fakes.dart';
import '../test/widgets_test.dart' show harness;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader('Plus Jakarta Sans')
      ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans[wght].ttf'));
    await loader.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  for (final width in [320.0, 390.0, 1440.0]) {
    testWidgets('capture places $width', (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final auth = FakeAuthRepository();
      addTearDown(auth.changes.close);
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('capture'),
          child: ProviderScope(
            overrides: [
              googlePlacesEnabledProvider.overrideWithValue(true),
              placesRepositoryProvider.overrideWithValue(WidgetPlaces()),
              stopLabelsProvider.overrideWithValue(
                StopLabels(['Aluva', 'Kaloor']),
              ),
            ],
            child: harness(const AppShell(), FakeTransitRepository(), auth),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('search-from')), 'Eda');
      if (width < 768)
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('Edappally'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const ValueKey('capture')),
        matchesGoldenFile('screenshots/places-${width.toInt()}.png'),
      );
    });
  }
  for (final entry in {
    'reference-home-no-ads': const Size(412, 1600),
    'desktop-home': const Size(1440, 1000),
    'desktop-home-no-ads': const Size(1440, 1000),
    'mobile-home-no-ads': const Size(390, 844),
    'mobile-home': const Size(390, 844),
    'mobile-home-full': const Size(390, 1700),
    'mobile-sponsor-large-text': const Size(390, 1700),
    'narrow-home': const Size(320, 740),
    'narrow-home-full-no-ads': const Size(320, 1700),
    'mobile-large-text-no-ads': const Size(390, 1700),
    'mobile-results': const Size(390, 844),
    'narrow-results': const Size(320, 740),
    'mobile-results-large-text': const Size(390, 844),
    'mobile-results-full': const Size(390, 1700),
  }.entries) {
    testWidgets('capture ${entry.key}', (tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final auth = FakeAuthRepository();
      addTearDown(auth.changes.close);
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('capture'),
          child: harness(
            const AppShell(),
            FakeTransitRepository(),
            auth,
            sampleSponsors: !entry.key.endsWith('no-ads'),
            textScaler: TextScaler.linear(
              entry.key.contains('large-text') ? 2 : 1,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (entry.key.contains('results')) {
        await tester.tap(find.byKey(const ValueKey('show-bus-results')));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const ValueKey('capture')),
        matchesGoldenFile('screenshots/${entry.key}.png'),
      );
    });
  }
  for (final width in [320.0, 390.0, 760.0]) {
    testWidgets('capture sponsor banner $width', (tester) async {
      tester.view.physicalSize = Size(width, 360);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final auth = FakeAuthRepository();
      addTearDown(auth.changes.close);
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('capture'),
          child: harness(
            const Scaffold(
              body: Padding(
                padding: EdgeInsets.all(16),
                child: SponsoredCarousel(),
              ),
            ),
            FakeTransitRepository(),
            auth,
            sampleSponsors: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const ValueKey('capture')),
        matchesGoldenFile('screenshots/sponsor-banner-${width.toInt()}.png'),
      );
    });
  }
  for (final width in [390.0, 1440.0]) {
    for (final tab in ['Routes', 'Owner', 'Tracking', 'Crew']) {
      testWidgets('capture $width $tab', (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final auth = FakeAuthRepository();
        addTearDown(auth.changes.close);
        await tester.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('capture'),
            child: harness(
              const AppShell(),
              FakeTransitRepository(),
              auth,
              sampleSponsors: true,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          width < 1000
              ? find.descendant(
                  of: find.byType(NavigationBar),
                  matching: find.text(tab),
                )
              : find.widgetWithText(TextButton, tab),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byKey(const ValueKey('capture')),
          matchesGoldenFile(
            'screenshots/${width < 1000 ? 'mobile' : 'desktop'}-${tab.toLowerCase()}.png',
          ),
        );
      });
    }
  }
  for (final scenario in [
    'mobile-workspace',
    'desktop-workspace',
    'business-editor',
    'route-editor',
    'timetable-editor',
    'timetable-editor-large-text',
    'business-keyboard',
    'delete-confirmation',
    'stop-details',
  ]) {
    testWidgets('capture $scenario', (tester) async {
      final largeText = scenario.endsWith('large-text');
      tester.view.physicalSize = Size(
        scenario == 'desktop-workspace'
            ? 1440
            : largeText
            ? 320
            : 390,
        1000,
      );
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final auth = FakeAuthRepository(
        user: const AuthUser(id: 'owner', email: 'owner@example.com'),
      );
      addTearDown(auth.changes.close);
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('capture'),
          child: harness(
            const AppShell(),
            FakeTransitRepository(services: [service('review-service')]),
            auth,
            textScaler: TextScaler.linear(largeText ? 2 : 1),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Owner account'));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(OwnerPage));
      switch (scenario) {
        case 'business-editor':
        case 'business-keyboard':
          openEditor<void>(context, const BusinessEditor());
        case 'route-editor':
          openEditor<void>(
            context,
            const RouteEditor(business: business, route: route),
          );
        case 'timetable-editor':
        case 'timetable-editor-large-text':
          openEditor<void>(
            context,
            ServiceEditor(
              business: business,
              route: route,
              service: service('review-service'),
            ),
          );
        case 'delete-confirmation':
          confirmDelete(context, route.name);
        case 'stop-details':
          showStopTimings(
            context,
            service('review-service'),
            from: 'Aluva',
            to: 'Kaloor',
            day: 'Friday',
          );
      }
      await tester.pumpAndSettle();
      if (scenario == 'business-keyboard') {
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        addTearDown(tester.view.resetViewInsets);
        await tester.tap(find.byKey(const ValueKey('business-name')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Save business'));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const ValueKey('capture')),
        matchesGoldenFile('screenshots/$scenario.png'),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
