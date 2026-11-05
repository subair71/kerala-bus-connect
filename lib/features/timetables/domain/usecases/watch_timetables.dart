import '../entities/business_entity.dart';
import '../entities/route_entity.dart';
import '../entities/service_entity.dart';
import '../repositories/transit_repository.dart';

class WatchTimetables {
  final TransitRepository repository;
  const WatchTimetables(this.repository);
  Stream<List<ServiceEntity>> published() => repository.getPublishedServices();
  Stream<List<BusinessEntity>> businesses(String ownerId) =>
      repository.getOwnerBusinesses(ownerId);
  Stream<List<RouteEntity>> routes(String businessId) =>
      repository.getBusinessRoutes(businessId);
  Stream<List<ServiceEntity>> ownerServices(String ownerId) =>
      repository.getOwnerServices(ownerId);
}
