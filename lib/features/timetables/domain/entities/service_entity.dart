import 'package:equatable/equatable.dart';

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
  final List<String> offDays;
  final String? offTimingsNote;
  final bool published;
  final bool operatingDaysKnown;

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
    required this.offDays,
    this.offTimingsNote,
    this.published = true,
    this.operatingDaysKnown = true,
  });

  /// Returns only supplied times; an unknown stop never inherits a departure.
  int? scheduledTime(String stop) {
    for (final entry in stopTimings.entries) {
      if (entry.key.trim().toLowerCase() == stop.trim().toLowerCase())
        return entry.value;
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
    offDays,
    offTimingsNote,
    published,
    operatingDaysKnown,
  ];
}
