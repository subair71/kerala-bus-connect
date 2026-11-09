import '../../../../core/errors/app_failure.dart';
import '../../../timetables/domain/entities/service_entity.dart';

class BusEntity {
  final String id, ownerId, businessId, name;
  const BusEntity({
    required this.id,
    required this.ownerId,
    required this.businessId,
    required this.name,
  });
}

class TripStop {
  final String id, name;

  /// Minutes since midnight of the service date; -1 means not entered.
  final int minutes;
  final int? arrivalMinutes;
  const TripStop(this.id, this.name, this.minutes, {this.arrivalMinutes});

  TripStop copyWith({String? name, int? minutes, int? arrivalMinutes}) => TripStop(
    id, name ?? this.name, minutes ?? this.minutes,
    arrivalMinutes: arrivalMinutes ?? (this.arrivalMinutes == null ? null :
      this.arrivalMinutes! + (minutes == null ? 0 : minutes - this.minutes)),
  );
}

class TripPlan {
  final String id, revision, routeId;
  final List<TripStop> stops;
  final Set<String> offDays;
  final String note;
  final bool active;

  TripPlan({
    this.id = '',
    this.revision = '',
    this.routeId = '',
    required List<TripStop> stops,
    Set<String> offDays = const {},
    this.note = '',
    this.active = true,
  }) : stops = List.unmodifiable(stops),
       offDays = Set.unmodifiable(offDays);

  factory TripPlan.fromService(ServiceEntity service) => TripPlan(
    id: service.id,
    revision: service.scheduleRevision,
    routeId: service.routeId,
    stops: [
      for (var i = 0; i < service.stops.length; i++)
        TripStop(
          i < service.stopIds.length ? service.stopIds[i] : 'legacy-$i',
          service.stops[i],
          service.scheduledTime(service.stops[i]) ?? -1,
          arrivalMinutes: service.arrivalStopTimings[service.stops[i]],
        ),
    ],
    offDays: service.offDays.toSet(),
    note: service.offTimingsNote ?? '',
    active: service.published,
  );

  TripPlan copyWith({
    List<TripStop>? stops,
    Set<String>? offDays,
    String? note,
    bool? active,
  }) => TripPlan(
    id: id,
    revision: revision,
    routeId: routeId,
    stops: stops ?? this.stops,
    offDays: offDays ?? this.offDays,
    note: note ?? this.note,
    active: active ?? this.active,
  );

  void validate() {
    if (stops.length < 2 || stops.length > 100) {
      throw const AppFailure(
        'Add an origin and destination (up to 100 stops).',
      );
    }
    if (stops.any((s) => s.name.trim().isEmpty || s.id.isEmpty)) {
      throw const AppFailure('Enter a name for every stop.');
    }
    if (stops.map((s) => s.id).toSet().length != stops.length ||
        stops.map((s) => s.name.trim().toLowerCase()).toSet().length !=
            stops.length) {
      throw const AppFailure('Give each stop a distinct name.');
    }
    final departure = stops.first.minutes;
    if (departure < 0 || departure >= 1440) {
      throw const AppFailure('Choose a departure time on the service date.');
    }
    var previous = departure - 1;
    for (final stop in stops) {
      if (stop.minutes < 0) {
        throw const AppFailure('Set a time for every stop.');
      }
      if (stop.minutes <= previous || stop.minutes - departure >= 1440) {
        throw const AppFailure(
          'Times must increase along the route within 24 hours. '
          'Choose Next day explicitly for overnight stops.',
        );
      }
      if (stop.arrivalMinutes != null &&
          (stop.arrivalMinutes! > stop.minutes || stop.arrivalMinutes! <= previous)) {
        throw const AppFailure('Arrival must follow the previous stop and precede departure.');
      }
      previous = stop.minutes;
    }
    const days = {
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    };
    if (offDays.length >= 7 || !days.containsAll(offDays)) {
      throw const AppFailure('Select at least one valid operating day.');
    }
  }

  /// Shift only configured times. Missing times remain missing.
  TripPlan shiftDeparture(int departure) {
    if (departure < 0 || departure >= 1440) {
      throw const AppFailure('Choose a valid departure on the service date.');
    }
    final old = stops.first.minutes;
    final difference = old < 0 ? 0 : departure - old;
    final shifted = [
      for (var i = 0; i < stops.length; i++)
        stops[i].copyWith(
          minutes: i == 0
              ? departure
              : stops[i].minutes < 0
              ? -1
              : stops[i].minutes + difference,
        ),
    ];
    if (shifted
        .skip(1)
        .any(
          (s) =>
              s.minutes != -1 &&
              (s.minutes < departure || s.minutes - departure >= 1440),
        )) {
      throw const AppFailure('This shift would put a stop before departure.');
    }
    return copyWith(stops: shifted);
  }

  TripPlan returnTrip(int departure) {
    validate();
    if (departure < 0 || departure >= 1440) {
      throw const AppFailure('Choose a return departure on the service date.');
    }
    final finish = stops.last.minutes;
    return TripPlan(
      stops: [
        for (var i = stops.length - 1; i >= 0; i--)
          TripStop(
            'return-${stops[i].id}',
            stops[i].name,
            departure + finish - stops[i].minutes,
          ),
      ],
      offDays: offDays,
      note: note,
    );
  }

  List<int> expectedTimes(Map<String, int> delays) {
    validate();
    if (delays.keys.any((id) => !stops.any((s) => s.id == id)) ||
        delays.values.any((minutes) => minutes < 0 || minutes > 1440)) {
      throw const AppFailure(
        'Use a delay of 0–1440 minutes at a current stop.',
      );
    }
    var cumulative = 0;
    return [
      for (final stop in stops)
        stop.minutes + (cumulative += delays[stop.id] ?? 0),
    ];
  }
}

String serviceDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

class DailyAdjustment {
  final String tripId, serviceDate, scheduleRevision;
  final Map<String, int> delays;
  final RunningStatus status;
  DailyAdjustment({
    required this.tripId,
    required this.serviceDate,
    required this.scheduleRevision,
    required Map<String, int> delays,
    RunningStatus? status,
  }) : status =
           status ??
           (delays.values.any((d) => d > 0)
               ? RunningStatus.delayed
               : RunningStatus.scheduled),
       delays = Map.unmodifiable(delays);

  ServiceEntity apply(ServiceEntity service) {
    if (service.id != tripId || service.scheduleRevision != scheduleRevision) {
      return service;
    }
    final plan = TripPlan.fromService(service);
    final times = plan.expectedTimes(delays);
    return service.withExpected(
      {
        for (var i = 0; i < plan.stops.length; i++)
          plan.stops[i].name: times[i],
      },
      serviceDate,
      status: status,
    );
  }
}
