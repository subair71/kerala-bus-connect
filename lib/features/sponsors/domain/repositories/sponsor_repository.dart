import '../entities/sponsored_ad.dart';

abstract interface class SponsorRepository {
  Stream<List<SponsoredAd>> watch(String location);
}
