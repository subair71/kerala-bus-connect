import '../../../../core/utils/sample_ids.dart';
import '../../domain/entities/business_entity.dart';
import '../../domain/entities/route_entity.dart';
import '../../domain/entities/service_entity.dart';
import '../../domain/repositories/transit_repository.dart';
import '../datasources/transit_remote_data_source.dart';

class TransitRepositoryImpl implements TransitRepository {
  final TransitRemoteDataSource _remoteDataSource;

  TransitRepositoryImpl(this._remoteDataSource);

  @override
  Stream<List<ServiceEntity>> getPublishedServices() =>
      _remoteDataSource.getPublishedServices();

  @override
  Stream<List<BusinessEntity>> getOwnerBusinesses(String ownerId) =>
      _remoteDataSource.getOwnerBusinesses(ownerId);

  @override
  Stream<List<RouteEntity>> getBusinessRoutes(String businessId) =>
      _remoteDataSource.getBusinessRoutes(businessId);

  @override
  Stream<List<ServiceEntity>> getOwnerServices(String ownerId) =>
      _remoteDataSource.getOwnerServices(ownerId);

  @override
  Future<String> createBusiness({
    required String ownerId,
    required String name,
  }) {
    requireLiveIds([ownerId]);
    return _remoteDataSource.addBusiness({'ownerId': ownerId, 'name': name});
  }

  @override
  Future<void> updateBusiness({
    required String businessId,
    required String ownerId,
    required String name,
  }) {
    requireLiveIds([ownerId, businessId]);
    return _remoteDataSource.updateBusiness(businessId, {
      'name': name,
      'ownerId': ownerId,
    });
  }

  @override
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
  }) {
    requireLiveIds([ownerId, businessId, returnOfRouteId]);
    return _remoteDataSource.addRoute({
      'ownerId': ownerId,
      'businessId': businessId,
      'businessName': businessName,
      'name': name,
      'startStop': startStop,
      'endStop': endStop,
      'stops': stops,
      'isReturn': isReturn,
      if (returnOfRouteId != null) 'returnOfRouteId': returnOfRouteId,
    });
  }

  @override
  Future<void> updateRoute({
    required String routeId,
    required String ownerId,
    required String name,
    required String startStop,
    required String endStop,
    required List<String> stops,
  }) {
    requireLiveIds([ownerId, routeId]);
    return _remoteDataSource.updateRoute(routeId, {
      'ownerId': ownerId,
      'name': name,
      'startStop': startStop,
      'endStop': endStop,
      'stops': stops,
    });
  }

  @override
  Future<void> deleteRoute(String routeId) async {
    requireLiveIds([routeId]);
    await _remoteDataSource.deleteRoute(routeId);
  }

  @override
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
  }) {
    requireLiveIds([ownerId, businessId, routeId]);
    return _remoteDataSource.addService({
      'ownerId': ownerId,
      'businessId': businessId,
      'routeId': routeId,
      'businessName': businessName,
      'routeName': routeName,
      'busName': busName,
      'stops': stops,
      'departureMinutes': departureMinutes,
      'stopTimings': stopTimings,
      'offDays': offDays,
      'offTimingsNote': offTimingsNote,
      'published': true,
    });
  }

  @override
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
  }) {
    requireLiveIds([ownerId, businessId, routeId, serviceId]);
    return _remoteDataSource.updateService(serviceId, {
      'ownerId': ownerId,
      'businessId': businessId,
      'routeId': routeId,
      'businessName': businessName,
      'routeName': routeName,
      'busName': busName,
      'stops': stops,
      'departureMinutes': departureMinutes,
      'stopTimings': stopTimings,
      'offDays': offDays,
      'offTimingsNote': offTimingsNote,
      'published': true,
    });
  }

  @override
  Future<void> deleteService(String serviceId) async {
    requireLiveIds([serviceId]);
    await _remoteDataSource.deleteService(serviceId);
  }
}
