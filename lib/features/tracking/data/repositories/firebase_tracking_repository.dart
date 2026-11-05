import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/data/display_fields.dart';
import '../../domain/entities/tracking_preview.dart';
import '../../domain/repositories/tracking_repository.dart';

class FirebaseTrackingRepository implements TrackingRepository {
  final FirebaseFirestore firestore;
  const FirebaseTrackingRepository(this.firestore);
  @override
  Stream<List<TrackingPreview>> watch() => firestore.collection('tracking_previews')
    .snapshots().map((snapshot) => snapshot.docs.map((doc) {
      final data = doc.data();
      final current = data['currentStop'];
      return TrackingPreview(displayText(data['vehicle'], 'Vehicle unavailable'),
        stringList(data['stops']), current is int && current >= 0 ? current : -1);
    }).toList());
}
