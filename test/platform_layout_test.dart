import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kerala_bus_connect/core/theme/app_theme.dart';
import 'package:kerala_bus_connect/core/theme/home_theme.dart';
import 'package:kerala_bus_connect/features/platform/presentation/pages/platform_console.dart';
import 'package:kerala_bus_connect/features/platform/presentation/providers/platform_providers.dart';

Widget consoleHarness({required bool admin, double scale = 1}) => ProviderScope(
  overrides: [
    platformRecordsProvider.overrideWith(
      (ref, key) async => {
        'records': [
          {
            'id': 'test-record',
            'name': 'Thrissur business',
            'status': 'pending',
            'pricePaise': 49900,
            'commissionPaise': 14970,
          },
        ],
        'cursor': null,
      },
    ),
  ],
  child: MaterialApp(
    theme: HomeTheme.from(AppTheme.lightTheme),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: PlatformConsole(admin: admin),
  ),
);
void main() {
  for (final width in [320.0, 390.0, 1200.0]) {
    for (final admin in [false, true]) {
      testWidgets(
        'platform dashboard $width admin=$admin keeps controls within viewport',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            consoleHarness(admin: admin, scale: width == 320 ? 1.5 : 1),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
            find.text(
              admin
                  ? 'Platform administration'
                  : 'Your advertising partnerships',
            ),
            findsOneWidget,
          );
        },
      );
    }
  }
}
