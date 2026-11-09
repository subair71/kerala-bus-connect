import '../../../../core/errors/app_failure.dart';
import 'trip_plan.dart';

/// Durations come from an approved route or owner supplied road estimates.
/// Suggestions are local drafts; only the existing review/save action publishes.
TripPlan suggestTimetable(
  TripPlan plan,
  List<int> travelMinutes, {
  double factor = 1,
  int stopMinutes = 1,
  Map<String, int> majorStopMinutes = const {},
  bool preserveEntered = true,
}) {
  if (plan.stops.length < 2 ||
      travelMinutes.length != plan.stops.length - 1 ||
      travelMinutes.any((m) => m < 1 || m > 1439) ||
      !factor.isFinite ||
      factor < 0.5 ||
      factor > 3 ||
      stopMinutes < 0 ||
      stopMinutes > 60 ||
      majorStopMinutes.values.any((m) => m < 0 || m > 120) ||
      plan.stops.first.minutes < 0) {
    throw const AppFailure('Set departure and valid travel durations first.');
  }
  final stops = [plan.stops.first];
  for (var i = 1; i < plan.stops.length; i++) {
    final previous = plan.stops[i - 1];
    final dwell = i == 1
        ? 0
        : stopMinutes + (majorStopMinutes[previous.id] ?? 0);
    final suggested =
        stops.last.minutes + (travelMinutes[i - 1] * factor).ceil() + dwell;
    final existing = plan.stops[i];
    stops.add(
      existing.copyWith(
        minutes: preserveEntered && existing.minutes >= 0
            ? existing.minutes
            : suggested,
      ),
    );
  }
  final result = plan.copyWith(stops: stops);
  result.validate();
  return result;
}
