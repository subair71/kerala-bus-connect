import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kerala_bus_connect/core/providers/clock_provider.dart';
import 'package:kerala_bus_connect/features/timetables/domain/entities/service_entity.dart';
import 'package:kerala_bus_connect/features/timetables/presentation/widgets/service_card.dart';

void main() {
  testWidgets('midnight boarding uses the trip starting day and correct countdown', (tester) async {
    const service = ServiceEntity(
      id: 'night', ownerId: 'owner', businessId: 'business', routeId: 'route',
      businessName: 'Operator', routeName: 'Night route', busName: 'Night bus',
      stops: ['A', 'B', 'C'], departureMinutes: 1430,
      stopTimings: {'A': 1430, 'B': 1450, 'C': 1470},
      offDays: ['Sunday'], serviceDate: '2026-11-07',
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        clockProvider.overrideWith((ref) => Stream.value(DateTime.utc(2026, 11, 8, 0, 5))),
      ],
      child: const MaterialApp(home: Scaffold(body: ServiceCard(
        service: service, from: 'B', to: 'C', compact: true,
      ))),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Scheduled in 5 min'), findsOneWidget);
    expect(find.textContaining('Not operating'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
