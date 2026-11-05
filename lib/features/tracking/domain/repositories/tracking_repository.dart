import '../entities/tracking_preview.dart';
abstract interface class TrackingRepository {
  Stream<List<TrackingPreview>> watch();
}
