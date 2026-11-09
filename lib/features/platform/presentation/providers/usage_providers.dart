import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../data/usage_tracker.dart';
import 'platform_providers.dart';

final usageTrackerProvider = Provider(
  (ref) => UsageTracker(ref.watch(platformRepositoryProvider)),
);
final analyticsConsentProvider = AsyncNotifierProvider<AnalyticsConsent, bool>(
  AnalyticsConsent.new,
);

class AnalyticsConsent extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final tracker = ref.watch(usageTrackerProvider);
    final consent = await tracker.consent();
    if (consent) await tracker.record('session');
    return consent;
  }
  Future<void> change(bool value) async {
    await ref.read(usageTrackerProvider).setConsent(value);
    if (ref.mounted) state = AsyncData(value);
    if (value) await ref.read(usageTrackerProvider).record('session');
  }
}

final adExposuresProvider =
    AsyncNotifierProvider<AdExposures, Map<String, int>>(AdExposures.new);

class AdExposures extends AsyncNotifier<Map<String, int>> {
  @override
  Future<Map<String, int>> build() =>
      ref.watch(usageTrackerProvider).exposures();
  Future<void> shown(String id) async {
    final counts = {...?state.asData?.value};
    if ((counts[id] ?? 0) >= 3) return;
    counts[id] = (counts[id] ?? 0) + 1;
    state = AsyncData(counts);
    await ref.read(usageTrackerProvider).saveExposures(counts);
    await ref.read(usageTrackerProvider).record('ad_impression', adId: id);
  }
}
