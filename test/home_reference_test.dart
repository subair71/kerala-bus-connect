import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kerala_bus_connect/app/app_shell.dart';
import 'package:kerala_bus_connect/features/passenger/presentation/providers/home_service_providers.dart';
import 'package:kerala_bus_connect/features/timetables/presentation/widgets/service_card.dart';
import 'package:kerala_bus_connect/features/timetables/presentation/widgets/train_route_view.dart';
import 'support/fakes.dart';
import 'widgets_test.dart' show harness;

void main() {
  test('fare fixtures are restricted to known sample services', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(homeServiceDetailsProvider('demo:service-antony')).fareRupees, 38);
    expect(container.read(homeServiceDetailsProvider('demo:service-unknown')).fareRupees, isNull);
    expect(container.read(homeServiceDetailsProvider('real-service-antony')).fareRupees, isNull);
  });

  testWidgets('home advisory and corridor controls open existing information', (tester) async {
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = FakeAuthRepository();
    addTearDown(auth.changes.close);
    await tester.pumpWidget(harness(const AppShell(), FakeTransitRepository(services: [service('real')]), auth));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Transit advisory'));
    await tester.pumpAndSettle();
    expect(find.textContaining('not live GPS tracking'), findsWidgets);
    await tester.tap(find.byTooltip('Close advisory'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View corridor stops'));
    await tester.pumpAndSettle();
    expect(find.byType(TrainRouteView), findsOneWidget);
    await tester.tap(find.byTooltip('Close stop timings'));
    await tester.pumpAndSettle();
    expect(find.text('Fare unavailable'), findsOneWidget);
    expect(find.text('GPS Live Tracked'), findsNothing);
    expect(find.text('On Time'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact real records reject demo fare and preserve midnight', (tester) async {
    final auth = FakeAuthRepository();
    addTearDown(auth.changes.close);
    await tester.pumpWidget(harness(
      Scaffold(body: ServiceCard(service: service('real', departure: 0), compact: true,
        demoFare: 38, demoFareLabel: 'Sample fare', from: 'Aluva', to: 'Kaloor')),
      FakeTransitRepository(), auth));
    await tester.pumpAndSettle();
    expect(find.text('12:00 AM'), findsOneWidget);
    expect(find.text('Fare unavailable'), findsOneWidget);
    expect(find.text('₹38'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact sample fare remains explicitly labelled', (tester) async {
    final auth = FakeAuthRepository();
    addTearDown(auth.changes.close);
    await tester.pumpWidget(harness(
      Scaffold(body: ServiceCard(service: service('demo:service-antony'), compact: true,
        demoFare: 0, demoFareLabel: 'Sample fare', from: 'Aluva', to: 'Kaloor')),
      FakeTransitRepository(), auth));
    await tester.pumpAndSettle();
    expect(find.text('Demo'), findsOneWidget);
    expect(find.text('Sample fare'), findsOneWidget);
    expect(find.text('₹0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
