import 'dart:async';
import 'package:kerala_bus_connect/features/sponsors/domain/entities/sponsored_ad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kerala_bus_connect/app/app_shell.dart';
import 'package:kerala_bus_connect/core/theme/app_theme.dart';
import 'package:kerala_bus_connect/features/passenger/presentation/providers/search_providers.dart';
import 'package:kerala_bus_connect/features/sponsors/presentation/widgets/sponsored_carousel.dart';
import 'package:kerala_bus_connect/features/passenger/presentation/widgets/search_panel.dart';
import 'package:kerala_bus_connect/features/timetables/presentation/widgets/train_route_view.dart';
import 'support/fakes.dart';
import 'widgets_test.dart' show harness;

void main() {
  for (final size in [const Size(390, 844), const Size(1440, 1000)]) {
    testWidgets('sponsors appear once beside or below search at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final auth = FakeAuthRepository();
      addTearDown(auth.changes.close);
      await tester.pumpWidget(
        harness(
          const AppShell(),
          FakeTransitRepository(),
          auth,
          sampleSponsors: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SponsoredCarousel), findsOneWidget);
      if (size.width < 1000) {
        expect(
          tester.getBottomLeft(find.byType(SearchPanel)).dy,
          lessThanOrEqualTo(tester.getTopLeft(find.byType(SponsoredCarousel)).dy),
        );
      } else {
        expect(
          tester.getTopRight(find.byType(SearchPanel)).dx,
          lessThan(tester.getTopLeft(find.byType(SponsoredCarousel)).dx),
        );
      }
      expect(find.text('Sample advertisement'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in [
    const Size(320, 740),
    const Size(390, 844),
    const Size(768, 1024),
    const Size(1440, 1000),
  ]) {
    testWidgets('responsive navigation, long text and details at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final auth = FakeAuthRepository();
      addTearDown(auth.changes.close);
      await tester.pumpWidget(
        harness(
          Theme(data: AppTheme.lightTheme, child: const AppShell()),
          FakeTransitRepository(
            services: [
              service(
                'real',
                bus:
                    'A very long operator and bus service name for the Kerala corridor',
              ),
            ],
          ),
          auth,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (size.width < 768) {
        await tester.tap(find.byKey(const ValueKey('show-bus-results')));
        await tester.pumpAndSettle();
      }
      final scroller = size.width < 768
          ? find.byKey(const ValueKey('mobile-bus-results-list'))
          : find.byType(CustomScrollView).first;
      await tester.drag(scroller, const Offset(0, -650));
      await tester.pumpAndSettle();
      final timing = find.byKey(const ValueKey('stop-timings-real'));
      await tester.ensureVisible(timing);
      await tester.tap(timing);
      await tester.pumpAndSettle();
      expect(find.byType(TrainRouteView), findsWidgets);
      expect(
        find.descendant(
          of: find.byType(TrainRouteView),
          matching: find.byType(SponsoredCarousel),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Close stop timings'));
      await tester.pumpAndSettle();
      if (size.width < 768) {
        await tester.tap(find.byTooltip('Close bus results'));
        await tester.pumpAndSettle();
      }
      final routes = size.width < 1000
          ? find.descendant(
              of: find.byType(NavigationBar),
              matching: find.text('Routes'),
            )
          : find.widgetWithText(TextButton, 'Routes');
      await tester.tap(routes);
      await tester.pumpAndSettle();
      expect(find.byType(SponsoredCarousel), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in [
    const Size(320, 740),
    const Size(844, 390),
    const Size(390, 844),
  ]) {
    testWidgets('all sections remain usable with large text at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final auth = FakeAuthRepository();
      addTearDown(auth.changes.close);
      await tester.pumpWidget(
        harness(
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(size.width == 390 ? 2 : 1.5),
              ),
              child: const AppShell(),
            ),
          ),
          FakeTransitRepository(
            services: [service('real', bus: 'Long bus service name')],
          ),
          auth,
          sampleSponsors: size.width == 320,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final label in ['Routes', 'Owner', 'Tracking', 'Crew']) {
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(label),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: label);
      }
    });
  }

  testWidgets(
    'boarding changes update the carousel, with a usable narrow keyboard layout',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final auth = FakeAuthRepository();
      addTearDown(auth.changes.close);
      await tester.pumpWidget(
        harness(
          const AppShell(),
          FakeTransitRepository(),
          auth,
          sampleSponsors: true,
        ),
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(AppShell));
      final container = ProviderScope.containerOf(context);
      container.read(searchQueryProvider.notifier).from('Thrissur Round');
      container.read(searchQueryProvider.notifier).to('Palakkad Stand');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      expect(find.text('Local sponsors near Thrissur'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Next sponsor'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Next sponsor'));
      await tester.pumpAndSettle();
      expect(find.text('Everyday essentials, close by'), findsOneWidget);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pump();
      await tester.ensureVisible(find.byKey(const ValueKey('search-from')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('search-from')));
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'carousel safely changes from a second live ad to a single live ad',
    (tester) async {
      final stream = StreamController<List<SponsoredAd>>();
      final auth = FakeAuthRepository();
      addTearDown(stream.close);
      addTearDown(auth.changes.close);
      await tester.pumpWidget(
        harness(
          const AppShell(),
          FakeTransitRepository(),
          auth,
          sponsorStream: stream.stream,
        ),
      );
      stream.add([sponsor('first'), sponsor('second')]);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Next sponsor'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Next sponsor'));
      await tester.pumpAndSettle();
      expect(find.text('Offer second'), findsOneWidget);
      stream.add([
        const SponsoredAd(
          id: 'live-ad',
          location: 'Aluva',
          advertiser: 'Live advertiser',
          title: 'Live local offer',
          description: 'Published sponsor content',
          website: 'https://example.com',
        ),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Live local offer'), findsOneWidget);
      expect(find.text('Sample advertisement'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
