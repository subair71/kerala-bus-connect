import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerala_bus_connect/app/app_shell.dart';
import 'support/fakes.dart';
import 'support/passenger_harness.dart' show harness;

void main() {
  for (final width in [320.0, 390.0]) {
    testWidgets(
      'results keep the five tabs and use the last typed stop at $width',
      (t) async {
        t.view.physicalSize = Size(width, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final auth = FakeAuthRepository();
        addTearDown(auth.changes.close);
        await t.pumpWidget(
          harness(
            const AppShell(),
            FakeTransitRepository(services: [service('real')]),
            auth,
            textScaler: const TextScaler.linear(2),
          ),
        );
        await t.pumpAndSettle();
        await t.tap(find.text('Leaving from'));
        await t.pumpAndSettle();
        await t.enterText(find.byType(EditableText).first, 'Kalamassery');
        await t.testTextInput.receiveAction(TextInputAction.done);
        await t.pumpAndSettle();
        await t.scrollUntilVisible(
          find.text('Search buses'),
          120,
          scrollable: find.byType(Scrollable).first,
        );
        await Scrollable.ensureVisible(
          t.element(find.text('Search buses')),
          alignment: 0.5,
        );
        await t.pumpAndSettle();
        await t.tap(find.text('Search buses'));
        await t.pumpAndSettle();
        expect(find.text('Kalamassery → Kaloor'), findsOneWidget);
        await t.scrollUntilVisible(
          find.text('Test bus · Kaloor'),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Test bus · Kaloor'), findsOneWidget);
        expect(find.text('Local sponsor'), findsNothing);
        expect(find.text('Find bus'), findsOneWidget);
        expect(t.takeException(), isNull);
      },
    );
  }
}
