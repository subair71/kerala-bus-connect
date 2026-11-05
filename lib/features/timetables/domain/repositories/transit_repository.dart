import '../entities/business_entity.dart';
import '../entities/route_entity.dart';
import '../entities/service_entity.dart';

abstract class TransitRepository {
  Stream<List<ServiceEntity>> getPublishedServices();
  Stream<List<BusinessEntity>> getOwnerBusinesses(String ownerId);
  Stream<List<RouteEntity>> getBusinessRoutes(String businessId);
  Stream<List<ServiceEntity>> getOwnerServices(String ownerId);

  Future<String> createBusiness({
    required String ownerId,
    required String name,
  });
  Future<void> updateBusiness({
    required String businessId,
    required String ownerId,
    required String name,
  });

  Future<String> createRoute({
    required String ownerId,
    required String businessId,
    required String businessName,
    required String name,
    required String startStop,
    required String endStop,
    required List<String> stops,
    bool isReturn = false,
    String? returnOfRouteId,
  });

  Future<void> updateRoute({
    required String routeId,
    required String ownerId,
    required String name,
    required String startStop,
    required String endStop,
    required List<String> stops,
  });

  Future<void> deleteRoute(String routeId);

  Future<void> publishService({
    required String ownerId,
    required String businessId,
    required String routeId,
    required String businessName,
    required String routeName,
    required String busName,
    required List<String> stops,
    required int departureMinutes,
    required Map<String, int> stopTimings,
    required List<String> offDays,
    required String offTimingsNote,
  });

  Future<void> updateService({
    required String serviceId,
    required String ownerId,
    required String businessId,
    required String routeId,
    required String businessName,
    required String routeName,
    required String busName,
    required List<String> stops,
    required int departureMinutes,
    required Map<String, int> stopTimings,
    required List<String> offDays,
    required String offTimingsNote,
  });

  Future<void> deleteService(String serviceId);
}
