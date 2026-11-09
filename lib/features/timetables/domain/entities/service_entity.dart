import 'package:equatable/equatable.dart';

enum RunningStatus {
  scheduled('Scheduled'),
  onTime('On Time'),
  delayed('Delayed'),
  cancelled('Cancelled'),
  completed('Completed');

  final String label;
  const RunningStatus(this.label);
  static RunningStatus parse(Object? value) =>
      values.where((s) => s.name == value).firstOrNull ?? scheduled;
}

class ServiceEntity extends Equatable {
  final String id;
  final String ownerId;
  final String businessId;
  final String routeId;
  final String businessName;
  final String routeName;
  final String busName;
  final List<String> stops;
  final int departureMinutes;
  final Map<String, int> stopTimings;
  final Map<String, int> arrivalStopTimings;
  final List<String> offDays;
  final String? offTimingsNote;
  final bool published;
  final bool operatingDaysKnown;

  /// Non-null only for a previously confirmed local timetable snapshot.
  final DateTime? cachedAt;

  final String busId, scheduleRevision;
  final List<String> stopIds;
  final Map<String, int> expectedStopTimings;
  final String? serviceDate;
  final RunningStatus runningStatus;

  const ServiceEntity({
    required this.id,
    required this.ownerId,
    required this.businessId,
    required this.routeId,
    required this.businessName,
    required this.routeName,
    required this.busName,
    required this.stops,
    required this.departureMinutes,
    required this.stopTimings,
    this.arrivalStopTimings = const {},
    required this.offDays,
    this.offTimingsNote,
    this.published = true,
    this.operatingDaysKnown = true,
    this.busId = '',
    this.scheduleRevision = '',
    this.stopIds = const [],
    this.expectedStopTimings = const {},
    this.serviceDate,
    this.cachedAt,
    this.runningStatus = RunningStatus.scheduled,
  });

  int? expectedTime(String stop) =>
      expectedStopTimings[stop] ?? scheduledTime(stop);

  bool get hasDailyAdjustment =>
      expectedStopTimings.entries.any((e) => e.value != scheduledTime(e.key));

  ServiceEntity withExpected(
    Map<String, int> times,
    String date, {
    RunningStatus status = RunningStatus.delayed,
  }) => ServiceEntity(
    id: id,
    ownerId: ownerId,
    businessId: businessId,
    routeId: routeId,
    businessName: businessName,
    routeName: routeName,
    busName: busName,
    stops: stops,
    departureMinutes: departureMinutes,
    stopTimings: stopTimings,
    offDays: offDays,
    offTimingsNote: offTimingsNote,
    published: published,
    operatingDaysKnown: operatingDaysKnown,
    busId: busId,
    scheduleRevision: scheduleRevision,
    stopIds: stopIds,
    expectedStopTimings: Map.unmodifiable(times),
    serviceDate: date,
    runningStatus: status,
    cachedAt: cachedAt,
  );

  /// Returns only supplied times; an unknown stop never inherits a departure.
  int? scheduledTime(String stop) {
    final exact = stopTimings[stop];
    if (exact != null) return exact;
    final normalized = stop.trim().toLowerCase();
    for (final entry in stopTimings.entries) {
      if (entry.key.trim().toLowerCase() == normalized) return entry.value;
    }
    if (stops.isNotEmpty &&
        stops.first.toLowerCase() == stop.toLowerCase() &&
        departureMinutes >= 0) {
      return departureMinutes;
    }
    return null;
  }

  int getBoardingTime(String boardingQuery) {
    if (boardingQuery.isNotEmpty) {
      for (final entry in stopTimings.entries) {
        if (entry.key.toLowerCase() == boardingQuery.toLowerCase()) {
          return entry.value;
        }
      }
    }
    return departureMinutes;
  }

  int getDestinationTime(String destinationQuery, {required int fallback}) {
    if (destinationQuery.isNotEmpty) {
      for (final entry in stopTimings.entries) {
        if (entry.key.toLowerCase() == destinationQuery.toLowerCase()) {
          return entry.value;
        }
      }
    }
    return fallback;
  }

  @override
  List<Object?> get props => [
    id,
    ownerId,
    businessId,
    routeId,
    businessName,
    routeName,
    busName,
    stops,
    departureMinutes,
    stopTimings,
    arrivalStopTimings,
    offDays,
    offTimingsNote,
    published,
    operatingDaysKnown,
    busId,
    scheduleRevision,
    stopIds,
    expectedStopTimings,
    serviceDate,
    runningStatus,
    cachedAt,
  ];
}
