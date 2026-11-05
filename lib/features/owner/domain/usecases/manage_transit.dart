import '../../../../core/utils/sample_ids.dart';
import '../../../../core/constants/transit_constants.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../timetables/domain/entities/business_entity.dart';
import '../../../timetables/domain/entities/route_entity.dart';
import '../../../timetables/domain/entities/service_entity.dart';
import '../../../timetables/domain/repositories/transit_repository.dart';

class ManageTransit {
  final TransitRepository repository;
  const ManageTransit(this.repository);

  Future<String> saveBusiness(String ownerId, String name, {String? id}) async {
    requireLiveIds([ownerId, id]);
    final clean = name.trim();
    if (ownerId.isEmpty || clean.isEmpty)
      throw const AppFailure('Enter a business name.');
    if (id != null) {
      await repository.updateBusiness(
        businessId: id,
        ownerId: ownerId,
        name: clean,
      );
      return id;
    }
    return repository.createBusiness(ownerId: ownerId, name: clean);
  }

  Future<String> saveRoute({
    required String ownerId,
    required BusinessEntity business,
    required String name,
    required String from,
    required String to,
    required String intermediateStops,
    required bool returnRoute,
    String? routeId,
  }) async {
    requireLiveIds([ownerId, business.id, routeId]);
    if (business.ownerId != ownerId)
      throw const AppFailure('This business belongs to another account.');
    final start = from.trim(), end = to.trim();
    if (start.isEmpty ||
        end.isEmpty ||
        start.toLowerCase() == end.toLowerCase()) {
      throw const AppFailure('Enter distinct starting and ending stops.');
    }
    final stops = [
      start,
      ...intermediateStops
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty),
      end,
    ];
    if (stops.map((s) => s.toLowerCase()).toSet().length != stops.length) {
      throw const AppFailure(
        'Use distinct stop names so each stop has one arrival time.',
      );
    }
    final title = name.trim().isEmpty ? '$start → $end' : name.trim();
    if (routeId != null) {
      await repository.updateRoute(
        routeId: routeId,
        ownerId: ownerId,
        name: title,
        startStop: start,
        endStop: end,
        stops: stops,
      );
      return routeId;
    }
    final id = await repository.createRoute(
      ownerId: ownerId,
      businessId: business.id,
      businessName: business.name,
      name: title,
      startStop: start,
      endStop: end,
      stops: stops,
    );
    if (returnRoute) {
      await repository.createRoute(
        ownerId: ownerId,
        businessId: business.id,
        businessName: business.name,
        name: '$end → $start (Return)',
        startStop: end,
        endStop: start,
        stops: stops.reversed.toList(),
        isReturn: true,
        returnOfRouteId: id,
      );
    }
    return id;
  }

  Future<void> generateReturn(RouteEntity route, String ownerId) async {
    requireLiveIds([ownerId, route.id, route.businessId]);
    if (route.ownerId != ownerId)
      throw const AppFailure('This route belongs to another account.');
    if (route.stops.length < 2)
      throw const AppFailure('This route needs at least two stops.');
    final stops = route.stops.reversed.toList();
    await repository.createRoute(
      ownerId: ownerId,
      businessId: route.businessId,
      businessName: route.businessName,
      name: '${stops.first} → ${stops.last} (Return)',
      startStop: stops.first,
      endStop: stops.last,
      stops: stops,
      isReturn: true,
      returnOfRouteId: route.id,
    );
  }

  Future<void> deleteService(String id) async {
    requireLiveIds([id]);
    await repository.deleteService(id);
  }

  Future<void> deleteRoute(String id, List<ServiceEntity> existing) async {
    requireLiveIds([id]);
    if (existing.any((s) => s.routeId == id)) {
      throw const AppFailure(
        'Remove this route’s published timetables before deleting it.',
      );
    }
    await repository.deleteRoute(id);
  }

  Future<void> saveService({
    required String ownerId,
    required BusinessEntity business,
    required RouteEntity route,
    required String busName,
    required int departure,
    required Map<String, int> timings,
    required Set<String> offDays,
    required String note,
    required List<ServiceEntity> existing,
    String? serviceId,
  }) async {
    requireLiveIds([ownerId, business.id, route.id, serviceId]);
    if (business.ownerId != ownerId ||
        route.ownerId != ownerId ||
        route.businessId != business.id) {
      throw const AppFailure('Choose a route belonging to your business.');
    }
    if (offDays.any((day) => !weekDays.contains(day))) {
      throw const AppFailure('Choose valid operating days.');
    }
    final name = busName.trim();
    if (name.isEmpty)
      throw const AppFailure('Enter a bus name or registration number.');
    if (route.stops.length < 2 || departure < 0 || departure >= 1440) {
      throw const AppFailure('Choose a valid route and departure time.');
    }
    if (offDays.length == weekDays.length)
      throw const AppFailure('Select at least one operating day.');
    for (final service in existing) {
      if (service.id == serviceId ||
          service.busName.trim().toLowerCase() != name.toLowerCase())
        continue;
      final gap = (service.departureMinutes % 1440 - departure).abs();
      final overlaps = weekDays.any(
        (day) => !offDays.contains(day) && !service.offDays.contains(day),
      );
      if (overlaps && (gap < 30 || 1440 - gap < 30)) {
        throw const AppFailure(
          'This bus already departs within 30 minutes on an overlapping day.',
        );
      }
    }
    final normalized = <String, int>{};
    var previous = departure;
    for (var i = 0; i < route.stops.length; i++) {
      final stop = route.stops[i];
      if (i > 0 && (timings[stop] == null || timings[stop]! < 0)) {
        throw const AppFailure('Enter a time for every stop before publishing.');
      }
      var minutes = i == 0 ? departure : timings[stop]!;
      if (i > 0 && minutes < previous) minutes += 1440;
      if (minutes < previous || minutes - departure >= 1440) {
        throw const AppFailure(
          'Stop times must follow the route within 24 hours.',
        );
      }
      normalized[stop] = minutes;
      previous = minutes;
    }
    if (serviceId == null) {
      await repository.publishService(
        ownerId: ownerId,
        businessId: business.id,
        routeId: route.id,
        businessName: business.name,
        routeName: route.name,
        busName: name,
        stops: route.stops,
        departureMinutes: departure,
        stopTimings: normalized,
        offDays: offDays.toList(),
        offTimingsNote: note.trim(),
      );
    } else {
      await repository.updateService(
        serviceId: serviceId,
        ownerId: ownerId,
        businessId: business.id,
        routeId: route.id,
        businessName: business.name,
        routeName: route.name,
        busName: name,
        stops: route.stops,
        departureMinutes: departure,
        stopTimings: normalized,
        offDays: offDays.toList(),
        offTimingsNote: note.trim(),
      );
    }
  }
}
