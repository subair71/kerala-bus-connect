class StopPosition {
  final double latitude, longitude;
  const StopPosition(this.latitude, this.longitude);
}
class NearbyStop {
  final String id, name;
  final double distanceKm;
  final List<String> routeIds;
  const NearbyStop({required this.id, required this.name, required this.distanceKm,
    this.routeIds = const []});
}
abstract interface class LocationGateway {
  Future<StopPosition> locate({bool requestPermission = true});
}
