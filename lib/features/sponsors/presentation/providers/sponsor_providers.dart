import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/data/data_set.dart';
import '../../../../core/providers/cache_lifetime.dart';
import '../../../../core/providers/firebase_providers.dart';
import '../../../../core/providers/sample_fallback.dart';
import '../../../../core/utils/sample_ids.dart';
import '../../../passenger/presentation/providers/search_providers.dart';
import '../../data/fixtures/sponsor_samples.dart';
import '../../data/repositories/firebase_sponsor_repository.dart';
import '../../domain/entities/sponsored_ad.dart';
import '../../domain/repositories/sponsor_repository.dart';

final sponsorRepositoryProvider = Provider<SponsorRepository>(
  (ref) => FirebaseSponsorRepository(ref.watch(firestoreProvider)));
final sponsorLocationProvider = Provider.autoDispose((ref) =>
  sponsorLocation(ref.watch(debouncedSearchProvider.select((query) => query.from))));
final liveSponsorsProvider = StreamProvider.autoDispose.family<List<SponsoredAd>, String>((ref, location) {
  retainWhileIdle(ref, const Duration(seconds: 30));
  return ref.watch(sponsorRepositoryProvider).watch(location);
});
final sponsorsProvider = Provider.autoDispose<AsyncValue<DataSet<SponsoredAd>>>((ref) {
  final location = ref.watch(sponsorLocationProvider);
  return sampleFallback(ref.watch(liveSponsorsProvider(location)), sponsorSamples(location));
});
final sponsorPageProvider = NotifierProvider.autoDispose.family<SponsorPage, int, String>(SponsorPage.new);
class SponsorPage extends Notifier<int> {
  final String location;
  SponsorPage(this.location);
  @override
  int build() => 0;
  void select(int value) => state = value;
}
final openSponsorProvider = Provider((ref) => (SponsoredAd ad) async {
  if (isSampleId(ad.id)) return false;
  final uri = Uri.tryParse(ad.website ?? '');
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return false;
  return launchUrl(uri, mode: LaunchMode.externalApplication);
});
