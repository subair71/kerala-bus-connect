import '../../domain/entities/tracking_preview.dart';
import '../../domain/repositories/tracking_repository.dart';

class DemoTrackingRepository implements TrackingRepository {
  const DemoTrackingRepository();
  @override
  List<TrackingPreview> previews() => const [
    TrackingPreview('Demo bus 1', ['Aluva', 'Kalamassery', 'Edappally Toll', 'Kaloor'], 1),
    TrackingPreview('Demo bus 2', ['Fort Kochi', 'Thoppumpady', 'Menaka', 'Kaloor'], 2),
  ];
}
