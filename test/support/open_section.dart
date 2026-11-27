import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> openSection(WidgetTester tester, String name) async {
  const staff = {
    'Owner': 'Owner account',
    'Tracking': 'Route position preview',
    'Crew': 'Crew duty roster',
  };
  final parent = staff.containsKey(name) ? 'More' : name;
  final mobile = find.byType(NavigationBar).evaluate().isNotEmpty;
  final link = mobile
      ? find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(parent),
        )
      : find.widgetWithText(TextButton, parent);
  await tester.tap(link);
  await tester.pumpAndSettle();
  if (staff.containsKey(name)) {
    final row = find.widgetWithText(ListTile, staff[name]!);
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pumpAndSettle();
  }
}
