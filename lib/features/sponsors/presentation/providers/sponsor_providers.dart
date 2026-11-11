import '../../../platform/presentation/providers/platform_providers.dart';
import '../../../platform/presentation/providers/usage_providers.dart';
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
    if (ref.watch(platformEnabledProvider)) {
      final caps = ref.watch(adExposuresProvider).asData?.value ?? {};
      return ref
          .watch(targetedSponsorsProvider)
          .whenData(
            (ads) => DataSet(
              ads
                  .where(
                    (ad) =>
                        (caps[ad.id] ?? 0) < 3 &&
                        (ad.expiresAt ?? 0) >
                            DateTime.now().millisecondsSinceEpoch,
                  )
                  .toList(),
            ),
          );
    }
    final location = ref.watch(sponsorLocationProvider);
    final live = ref.watch(liveSponsorsProvider(location));
    if (live.isLoading && !live.hasValue) return const AsyncLoading();
    final ads = live.asData?.value
        .where((ad) => ad.active && ad.location == location)
        .toList();
    // Read-only previews remain the fallback for empty or unavailable ads.
    // Pending initial reads use skeletons; refreshes keep the current ads.
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
    if (ref.read(platformEnabledProvider))
      ref.read(usageTrackerProvider).record('ad_click', adId: ad.id);
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  },
);

final targetedSponsorsProvider = FutureProvider.autoDispose<List<SponsoredAd>>((
  ref,
) async {
  retainWhileIdle(ref, const Duration(seconds: 30));
  final query = ref.watch(debouncedSearchProvider);
  final routes = ref.watch(
    departureResultsProvider.select(
      (value) => (value.asData?.value ?? [])
          .map((s) => s.routeId)
          .where((id) => id.isNotEmpty)
          .toSet()
          .take(20)
          .join(','),
    ),
  );
  final response = await ref
      .watch(platformRepositoryProvider)
      .call('relevantAdvertisements', {
        'from': query.from,
        'to': query.to,
        'routeIds': routes.isEmpty ? <String>[] : routes.split(','),
        'stopIds': <String>[],
      });
  return [
    for (final raw in response['ads'] as List)
      SponsoredAd(
        id: raw['id'] as String,
        location: raw['location'] as String,
        advertiser: raw['advertiser'] as String,
        title: raw['title'] as String,
        description: raw['description'] as String,
        imageUrl: raw['imageUrl'] as String?,
        website: raw['website'] as String?,
        expiresAt: (raw['expiresAt'] as num).toInt(),
      ),
  ];
}, retry: (_, _) => null);
