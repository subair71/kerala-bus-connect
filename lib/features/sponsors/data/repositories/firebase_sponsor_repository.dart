import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/data/display_fields.dart';
import '../../domain/entities/sponsored_ad.dart';
import '../../domain/repositories/sponsor_repository.dart';

class FirebaseSponsorRepository implements SponsorRepository {
  final FirebaseFirestore firestore;
  const FirebaseSponsorRepository(this.firestore);
  @override
  Stream<List<SponsoredAd>> watch(String location) => firestore
      .collection('sponsored_ads')
      .where('location', isEqualTo: location)
      .where('active', isEqualTo: true)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) {
              final data = doc.data();
              return SponsoredAd(
                id: doc.id,
                location: location,
                advertiser: displayText(data['advertiser'], 'Local sponsor'),
                title: displayText(data['title'], 'Local advertisement'),
                description: displayText(
                  data['description'],
                  'Details unavailable',
                ),
                imageUrl: data['imageUrl'] is String
                    ? data['imageUrl'] as String
                    : null,
                website: data['website'] is String
                    ? data['website'] as String
                    : null,
                active: data['active'] == true,
              );
            })
            .where((ad) => ad.active)
            .toList(),
      );
}
