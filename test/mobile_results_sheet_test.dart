import 'package:kerala_bus_connect/core/widgets/loading_skeletons.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kerala_bus_connect/app/app_shell.dart';
import 'package:kerala_bus_connect/features/passenger/presentation/providers/search_providers.dart';
import 'package:kerala_bus_connect/features/passenger/presentation/widgets/mobile_bus_results_sheet.dart';
import 'package:kerala_bus_connect/features/sponsors/presentation/widgets/sponsored_carousel.dart';
import 'package:kerala_bus_connect/features/timetables/domain/entities/service_entity.dart';
import 'package:kerala_bus_connect/features/timetables/presentation/widgets/service_card.dart';
import 'support/fakes.dart';
import 'widgets_test.dart' show harness;

void main() {
  for (final width in [320.0, 390.0]) {
    testWidgets(
      'mobile results are modal, ad-free and usable at 2x text ($width)',
      (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final auth = FakeAuthRepository();
        addTearDown(auth.changes.close);
        await tester.pumpWidget(
          harness(
            const AppShell(),
            FakeTransitRepository(services: [service('real')]),
            auth,
            sampleSponsors: true,
            textScaler: const TextScaler.linear(2),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ServiceCard), findsNothing);
        await tester.ensureVisible(
          find.byKey(const ValueKey('show-bus-results')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('show-bus-results')));
        await tester.pumpAndSettle();
        expect(find.byType(MobileBusResultsSheet), findsOneWidget);
        expect(find.byType(ServiceCard), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(MobileBusResultsSheet),
            matching: find.byType(SponsoredCarousel),
          ),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('Close bus results'));
        await tester.pumpAndSettle();
        expect(find.byType(MobileBusResultsSheet), findsNothing);
        await tester.ensureVisible(
          find.byKey(const ValueKey('show-bus-results')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('show-bus-results')));
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(MobileBusResultsSheet), findsNothing);
        await tester.ensureVisible(
          find.byKey(const ValueKey('show-bus-results')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('show-bus-results')));
        await tester.pumpAndSettle();
        await tester.drag(
          find.byKey(const ValueKey('mobile-bus-results-list')),
          const Offset(0, 700),
        );
        await tester.pumpAndSettle();
        expect(find.byType(MobileBusResultsSheet), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'keyboard search opens the sheet with the latest un-debounced fields',
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
          FakeTransitRepository(services: [service('real')]),
          auth,
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AppShell)),
      );
      await tester.enterText(
        find.byKey(const ValueKey('search-to')),
        'Kalamassery',
      );
      expect(container.read(debouncedSearchProvider).to, 'Kaloor');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      expect(container.read(debouncedSearchProvider).to, 'Kalamassery');
      await tester.pumpAndSettle();
      expect(find.text('Aluva → Kalamassery'), findsOneWidget);
      expect(tester.testTextInput.isVisible, isFalse);
      await tester.tap(find.byTooltip('Close bus results'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('search-to')))
            .controller!
            .text,
        'Kalamassery',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'sheet presents loading, failed-data fallback and live recovery',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final auth = FakeAuthRepository();
      final stream = StreamController<List<ServiceEntity>>();
      addTearDown(auth.changes.close);
      addTearDown(stream.close);
      final repository = FakeTransitRepository()
        ..publishedOverride = stream.stream;
      await tester.pumpWidget(harness(const AppShell(), repository, auth));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('show-bus-results')),
      );
      await tester.tap(find.byKey(const ValueKey('show-bus-results')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(LoadingSliver), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      stream.addError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(find.text('Live data unavailable • Sample data'), findsOneWidget);
      stream.add([service('live', bus: 'Published bus')]);
      await tester.pumpAndSettle();
      expect(find.text('Published bus'), findsOneWidget);
      expect(find.text('Live data unavailable • Sample data'), findsNothing);
      expect(find.text('Sample fare'), findsNothing);
      expect(repository.publishedRequests, 1);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MobileBusResultsSheet)),
      );
      container.read(searchQueryProvider.notifier).to('Unmatched stop');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      expect(find.text('0 buses found'), findsOneWidget);
      expect(find.byType(ServiceCard), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
