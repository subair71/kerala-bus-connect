import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kerala_bus_connect/core/providers/clock_provider.dart';
import 'package:kerala_bus_connect/features/passenger/presentation/providers/search_providers.dart';
import 'package:kerala_bus_connect/features/passenger/presentation/widgets/search_panel.dart';
import 'support/fakes.dart';
import 'widgets_test.dart' show harness;

void main() {
  test(
    'journey dates cross a year boundary and future days clear today-only',
    () {
      final container = ProviderContainer(
        overrides: [
          clockProvider.overrideWithValue(
            AsyncData(DateTime(2026, 12, 31, 23, 59)),
          ),
        ],
      );
      addTearDown(container.dispose);
      final dates = container.read(journeyDatesProvider);
      expect(dates.first, DateTime(2026, 12, 31));
      expect(dates[1], DateTime(2027, 1, 1));
      expect(dates.last, DateTime(2027, 1, 6));
      final controller = container.read(searchQueryProvider.notifier);
      controller.runningToday(true);
      controller.journeyDate(dates[1]);
      expect(container.read(searchQueryProvider).filterDay, 'Friday');
      expect(container.read(searchQueryProvider).onlyRunningToday, isFalse);
      controller.day('All Days');
      expect(container.read(searchQueryProvider).filterDay, 'All Days');
    },
  );

  test(
    'the date strip advances at midnight without replacing typed stops',
    () async {
      final clock = StreamController<DateTime>();
      final container = ProviderContainer(
        overrides: [clockProvider.overrideWith((ref) => clock.stream)],
      );
      final subscription = container.listen(journeyDatesProvider, (_, _) {});
      addTearDown(() async {
        subscription.close();
        container.dispose();
        await clock.close();
      });
      clock.add(DateTime(2026, 12, 31, 23, 59));
      await container.read(clockProvider.future);
      container.read(searchQueryProvider.notifier).from('Thrissur');
      clock.add(DateTime(2027, 1, 1));
      await Future<void>.delayed(Duration.zero);
      expect(container.read(journeyDatesProvider).first, DateTime(2027, 1, 1));
      expect(container.read(searchQueryProvider).from, 'Thrissur');
    },
  );

  testWidgets('mobile divider swap, date selection and search stay connected', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = FakeAuthRepository();
    addTearDown(auth.changes.close);
    var searches = 0;
    await tester.pumpWidget(
      harness(
        Scaffold(
          body: SingleChildScrollView(
            child: SearchPanel(onSearch: () => searches++),
          ),
        ),
        FakeTransitRepository(),
        auth,
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('search-from')),
      'Thrissur',
    );
    await tester.tap(find.byTooltip('Swap stops'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('search-to')))
          .controller!
          .text,
      'Thrissur',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('search-from')))
          .controller!
          .text,
      'Kaloor',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('journey-date-1')));
    await tester.tap(find.byKey(const ValueKey('journey-date-1')));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SearchPanel)),
    );
    expect(container.read(searchQueryProvider).filterDay, 'Saturday');
    await tester.ensureVisible(find.byKey(const ValueKey('show-bus-results')));
    await tester.tap(find.byKey(const ValueKey('show-bus-results')));
    await tester.pumpAndSettle();
    expect(searches, 1);
    expect(container.read(debouncedSearchProvider).filterDay, 'Saturday');
    await tester.tap(find.byKey(const PageStorageKey('passenger-search-filters')));
    await tester.pumpAndSettle();
    expect(find.text('View corridor stops'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
