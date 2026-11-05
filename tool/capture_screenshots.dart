import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerala_bus_connect/app/app_shell.dart';
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
  for (final entry in {
    'reference-home-no-ads': const Size(412, 1600),
    'desktop-home': const Size(1440, 1000),
    'desktop-home-no-ads': const Size(1440, 1000),
    'mobile-home-no-ads': const Size(390, 844),
    'mobile-home': const Size(390, 844),
    'mobile-home-full': const Size(390, 1700),
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
  for (final tab in ['Routes', 'Owner', 'Tracking', 'Crew']) {
    testWidgets('capture mobile $tab', (tester) async {
      tester.view.physicalSize = const Size(390, 1000);
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
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(tab),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const ValueKey('capture')),
        matchesGoldenFile('screenshots/mobile-${tab.toLowerCase()}.png'),
      );
    });
  }
}
