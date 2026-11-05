import '../../../timetables/data/fixtures/transit_samples.dart';
import '../../domain/entities/tracking_preview.dart';
import '../../domain/repositories/tracking_repository.dart';

class DemoTrackingRepository implements TrackingRepository {
  const DemoTrackingRepository();
  @override
  Stream<List<TrackingPreview>> watch() => Stream.value(previews());
  List<TrackingPreview> previews() => const [
    TrackingPreview('St. Antony Express', TransitSamples.kochiStops, 1),
    TrackingPreview('Royal Travels', TransitSamples.thrissurStops, 2),
  ];
}
