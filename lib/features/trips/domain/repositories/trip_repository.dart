import '../entities/trip_plan.dart';
import '../../../timetables/domain/entities/business_entity.dart';

abstract class TripRepository {
  Stream<List<BusEntity>> watchBuses(String ownerId, String businessId);
  Stream<List<DailyAdjustment>> watchAdjustments(
    String date, {
    String? ownerId,
    List<String>? tripIds,
  });
  Future<void> saveBus(
    String ownerId,
    BusinessEntity business,
    String name, {
    BusEntity? bus,
  });
  Future<void> deleteBus(String ownerId, BusEntity bus);
  Future<String> saveTrip(
    String ownerId,
    BusinessEntity business,
    BusEntity bus,
    TripPlan trip,
  );
  Future<void> deleteTrip(String ownerId, BusEntity bus, TripPlan trip);
  Future<void> saveAdjustment(
    String ownerId,
    BusEntity bus,
    TripPlan trip,
    DailyAdjustment adjustment,
  );
  Future<void> resetAdjustment(
    String ownerId,
    BusEntity bus,
    TripPlan trip,
    String date,
  );
}
