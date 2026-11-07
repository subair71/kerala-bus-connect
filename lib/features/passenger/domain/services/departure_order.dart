import '../../../timetables/domain/entities/service_entity.dart';

/// Resolve each boarding time once, rather than scanning stops in every
/// comparison. Equal times preserve the incoming catalogue order.
List<ServiceEntity> orderDepartures(List<ServiceEntity> services, String from) {
  final term = from.trim().toLowerCase();
  final ranked = <({ServiceEntity service, int time, int order})>[];
  for (var i = 0; i < services.length; i++) {
    final service = services[i];
    final stop = term.isEmpty
        ? service.stops.firstOrNull
        : service.stops.where((stop) => stop.toLowerCase().contains(term)).firstOrNull;
    final time = stop == null ? null : service.expectedTime(stop);
    ranked.add((service: service, time: time == null || time < 0 ? 999999 : time, order: i));
  }
  ranked.sort((a, b) {
    final time = a.time.compareTo(b.time);
    return time != 0 ? time : a.order.compareTo(b.order);
  });
  return List.unmodifiable(ranked.map((entry) => entry.service));
}
