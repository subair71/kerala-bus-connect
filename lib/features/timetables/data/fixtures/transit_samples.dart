import '../../domain/entities/business_entity.dart';
import '../../domain/entities/route_entity.dart';
import '../../domain/entities/service_entity.dart';

/// Fictional review records only. Never seed these into Firebase.
abstract final class TransitSamples {
  static const ownerId = 'demo:owner';
  static const businesses = [
    BusinessEntity(id: 'demo:business-kochi', ownerId: ownerId, name: 'Cochin Transit'),
    BusinessEntity(id: 'demo:business-thrissur', ownerId: ownerId, name: 'Thrissur Transit'),
  ];
  static const kochiStops = ['Aluva', 'Kalamassery', 'Edappally Toll', 'Palarivattom', 'Kaloor'];
  static const thrissurStops = ['Thrissur Round', 'Pattikkad', 'Vadakkencherry', 'Alathur', 'Palakkad Stand'];
  static const routes = [
    RouteEntity(id: 'demo:route-aluva', ownerId: ownerId,
      businessId: 'demo:business-kochi', businessName: 'Cochin Transit',
      name: 'Aluva → Kaloor', startStop: 'Aluva', endStop: 'Kaloor', stops: kochiStops),
    RouteEntity(id: 'demo:route-thrissur', ownerId: ownerId,
      businessId: 'demo:business-thrissur', businessName: 'Thrissur Transit',
      name: 'Thrissur → Palakkad', startStop: 'Thrissur Round', endStop: 'Palakkad Stand', stops: thrissurStops),
  ];
  static final services = List<ServiceEntity>.unmodifiable([
    _service('antony', 'St. Antony Express', routes[0], 495, [0, 14, 26, 35, 43]),
    _service('swift', 'Swift Ordinary', routes[0], 515, [0, 15, 28, 40, 50]),
    _service('greenline', 'Greenline Transports', routes[0], 550, [0, 13, 25, 36, 45]),
    _service('fast', 'Fast Passenger', routes[1], 450, [0, 25, 45, 72, 100]),
    _service('royal', 'Royal Travels', routes[1], 480, [0, 20, 42, 68, 95]),
    _service('minnal', 'Minnal Express', routes[1], 525, [0, 18, 35, 55, 75]),
  ]);
  static ServiceEntity _service(String id, String name, RouteEntity route,
      int departure, List<int> offsets) => ServiceEntity(
    id: 'demo:service-$id', ownerId: ownerId, businessId: route.businessId,
    routeId: route.id, businessName: route.businessName, routeName: route.name,
    busName: name, stops: route.stops, departureMinutes: departure,
    stopTimings: {for (var i = 0; i < route.stops.length; i++) route.stops[i]: departure + offsets[i]},
    offDays: const [], offTimingsNote: 'Sample schedule • not for travel planning.',
  );
}
