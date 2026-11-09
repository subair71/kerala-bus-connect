import 'package:flutter_test/flutter_test.dart';
import 'package:kerala_bus_connect/features/trips/domain/entities/trip_plan.dart';
import 'package:kerala_bus_connect/features/trips/domain/entities/timetable_suggestion.dart';
import 'package:kerala_bus_connect/features/timetables/domain/entities/service_entity.dart';

void main() {
  final plan = TripPlan(
    stops: const [
      TripStop('a', 'A', 1430),
      TripStop('b', 'B', -1),
      TripStop('c', 'C', -1),
    ],
  );
  test('suggestions cross midnight, include dwell and remain drafts', () {
    final result = suggestTimetable(
      plan,
      [10, 20],
      factor: 1.5,
      stopMinutes: 2,
    );
    expect(result.stops.map((s) => s.minutes), [1430, 1445, 1477]);
    expect(plan.stops[1].minutes, -1);
    expect(result.shiftDeparture(1400).stops.last.minutes, 1447);
  });
  test('preserves entered manual times and rejects invalid intervals', () {
    final manual = plan.copyWith(
      stops: [
        plan.stops.first,
        const TripStop('b', 'B', 1450),
        plan.stops.last,
      ],
    );
    expect(
      suggestTimetable(manual, [10, 20], stopMinutes: 0).stops.last.minutes,
      1470,
    );
    expect(() => suggestTimetable(plan, [0, 20]), throwsA(isA<Exception>()));
  });
  test(
    'legacy delays infer status; explicit cancellations remain cancelled',
    () {
      expect(
        DailyAdjustment(
          tripId: 't',
          serviceDate: '2026-11-09',
          scheduleRevision: 'r',
          delays: {'a': 15},
        ).status,
        RunningStatus.delayed,
      );
      expect(
        DailyAdjustment(
          tripId: 't',
          serviceDate: '2026-11-09',
          scheduleRevision: 'r',
          delays: {},
          status: RunningStatus.cancelled,
        ).status,
        RunningStatus.cancelled,
      );
      expect(RunningStatus.parse('unknown'), RunningStatus.scheduled);
    },
  );
}
