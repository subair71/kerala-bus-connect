import '../entities/tracking_preview.dart';

const trackingPageSize = 20;

abstract interface class TrackingRepository {
  Stream<List<TrackingPreview>> watch({String? after});
}
