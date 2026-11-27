import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerala_bus_connect/app/app_shell.dart';
import 'support/fakes.dart';
import 'support/passenger_harness.dart' show harness;

void main() {
  for (final width in [320.0, 390.0, 1440.0]) {
    testWidgets('the PDF navigation and boarding-area sponsor fit at $width', (
      t,
    ) async {
      t.view.physicalSize = Size(width, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final auth = FakeAuthRepository();
      addTearDown(auth.changes.close);
      await t.pumpWidget(
        harness(
          const AppShell(),
          FakeTransitRepository(),
          auth,
          sampleSponsors: true,
          textScaler: const TextScaler.linear(1.5),
        ),
      );
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.text('Local sponsor'),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('SPONSORED · ALUVA'), findsOneWidget);
      expect(
        t.getTopLeft(find.text('Search buses')).dy,
        lessThan(t.getTopLeft(find.text('Local sponsor')).dy),
      );
      await t.tap(find.text('More').last);
      await t.pumpAndSettle();
      expect(find.text('Passenger tools'), findsOneWidget);
      expect(find.text('Local sponsor'), findsNothing);
      for (final label in [
        'Nearby stops',
        'Route position preview',
        'Service updates',
        'Owner sign in',
        'Crew duty roster',
      ]) {
        await t.scrollUntilVisible(
          find.text(label),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text(label), findsWidgets);
      }
      expect(find.text('Sample routes'), findsNothing);
      expect(find.text('Platform console'), findsNothing);
      expect(t.takeException(), isNull);
    });
  }
}
