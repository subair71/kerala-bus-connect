import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/data/data_set.dart';
import '../../../../core/providers/cache_lifetime.dart';
import '../../../../core/providers/firebase_providers.dart';
import '../../../../core/utils/sample_ids.dart';
import '../../../passenger/presentation/providers/search_providers.dart';
import '../../data/fixtures/sponsor_samples.dart';
import '../../data/repositories/firebase_sponsor_repository.dart';
import '../../domain/entities/sponsored_ad.dart';
import '../../domain/repositories/sponsor_repository.dart';

final sponsorRepositoryProvider = Provider<SponsorRepository>(
  (ref) => FirebaseSponsorRepository(ref.watch(firestoreProvider)),
);
final sponsorLocationProvider = Provider.autoDispose(
  (ref) => sponsorLocation(
    ref.watch(debouncedSearchProvider.select((query) => query.from)),
  ),
);
final sponsorCacheDurationProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 30),
);
final sponsorRotationIntervalProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 5),
);
final liveSponsorsProvider = StreamProvider.autoDispose
    .family<List<SponsoredAd>, String>(
      (ref, location) {
        retainWhileIdle(ref, ref.watch(sponsorCacheDurationProvider));
        return ref.watch(sponsorRepositoryProvider).watch(location);
      },
      // Firestore reconnects its own streams. Optional ads must not retry-loop
      // when a collection is unavailable or permission is denied.
      retry: (_, _) => null,
    );
final sponsorsProvider = Provider.autoDispose<AsyncValue<DataSet<SponsoredAd>>>(
  (ref) {
    final location = ref.watch(sponsorLocationProvider);
    final live = ref.watch(liveSponsorsProvider(location));
    final ads = live.asData?.value
        .where((ad) => ad.active && ad.location == location)
        .toList();
    // Read-only previews keep the home carousel usable while optional live ads
    // are pending, empty or unavailable. Never combine demo and live campaigns.
    return AsyncData(
      ads != null && ads.isNotEmpty
          ? DataSet(ads)
          : DataSet(
              sponsorSamples(location),
              isDemo: true,
              unavailable: live.hasError,
            ),
    );
  },
);
final sponsorPageProvider = NotifierProvider.autoDispose
    .family<SponsorPage, int, String>(SponsorPage.new);

class SponsorPage extends Notifier<int> {
  final String location;
  SponsorPage(this.location);
  @override
  int build() => 0;
  void select(int value) => state = value;
}

final openSponsorProvider = Provider(
  (ref) => (SponsoredAd ad) async {
    if (isSampleId(ad.id)) return false;
    final uri = Uri.tryParse(ad.website ?? '');
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  },
);

final dismissedSponsorLocationsProvider =
    NotifierProvider<SponsorDismissals, Set<String>>(SponsorDismissals.new);

/// Session-only dismissals survive tab changes; a new location has its own ads.
class SponsorDismissals extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};
  void dismiss(String location) => state = {...state, location};
}
