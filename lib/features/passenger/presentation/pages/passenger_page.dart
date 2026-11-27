import '../../../journeys/presentation/widgets/stop_map.dart';
import '../../../journeys/presentation/pages/discovery_pages.dart';
import '../../../platform/presentation/providers/usage_providers.dart';
import '../../../platform/presentation/providers/platform_providers.dart';
import '../../../../core/widgets/loading_skeletons.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../widgets/transit_advisory.dart';
import '../../../sponsors/presentation/widgets/sponsored_carousel.dart';
import '../../../timetables/presentation/widgets/train_route_view.dart';
import '../providers/search_providers.dart';
import '../widgets/search_panel.dart';
import '../widgets/departure_results.dart';
import '../widgets/mobile_bus_results_sheet.dart';

class PassengerPage extends StatelessWidget {
  const PassengerPage({super.key});
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1200),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide =
              constraints.maxWidth >= 1050 &&
              constraints.maxHeight >= 760 &&
              MediaQuery.textScalerOf(context).scale(14) <= 18;
          final mobile = constraints.maxWidth < 768;
          void openResults() => showMobileBusResults(context);
          final top = Column(
            children: [
              if (mobile) const _HomeMap(),
              SearchPanel(
                onSearch: mobile ? openResults : null,
                compact: mobile,
              ),
              if (mobile)
                ListTile(
                  leading: const Icon(Icons.outlined_flag),
                  title: const Text('Stops near me'),
                  subtitle: const Text('Choose a stop for departures'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      openScreen(context, 'Nearby stops', const NearbyPage()),
                ),

              const SizedBox(height: 12),
              const SponsoredCarousel(),
              const _AnalyticsChoice(),
            ],
          );
          if (mobile) {
            return CustomScrollView(
              key: const PageStorageKey('passenger-home'),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                  sliver: SliverToBoxAdapter(child: top),
                ),
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
                  sliver: SliverToBoxAdapter(child: TransitAdvisory()),
                ),
              ],
            );
          }
          final results = CustomScrollView(
            key: const PageStorageKey('passenger'),
            slivers: [
              if (!wide)
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                  sliver: SliverToBoxAdapter(child: top),
                ),
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                sliver: SliverToBoxAdapter(child: CatalogNotice()),
              ),
              const SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                sliver: DeparturesSliver(),
              ),
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 32),
                sliver: SliverToBoxAdapter(child: TransitAdvisory()),
              ),
            ],
          );
          if (!wide) return results;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(flex: 2, child: SearchPanel()),
                    const SizedBox(width: 20),
                    const Expanded(
                      child: Column(
                        children: [SponsoredCarousel(), _AnalyticsChoice()],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 2, child: results),
                    const Expanded(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(8, 12, 16, 24),
                        child: _TimelinePreview(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _TimelinePreview extends ConsumerWidget {
  const _TimelinePreview();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final first = ref.watch(
      departureResultsProvider.select(
        (value) => value.asData?.value.firstOrNull,
      ),
    );
    final query = ref.watch(debouncedSearchProvider);
    final loading = ref.watch(
      departureResultsProvider.select(
        (value) => value.isLoading && !value.hasValue,
      ),
    );
    if (loading)
      return const AppShimmer(
        label: 'Loading stop timings',
        child: SkeletonCard(layout: SkeletonLayout.timeline),
      );
    if (first == null) return const SizedBox.shrink();
    return Card(
      child: TrainRouteView(
        service: first,
        queryFrom: query.from,
        queryTo: query.to,
        effectiveDay: query.filterDay,
      ),
    );
  }
}

class _AnalyticsChoice extends ConsumerWidget {
  const _AnalyticsChoice();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(platformEnabledProvider)) return const SizedBox.shrink();
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      value: ref.watch(analyticsConsentProvider).asData?.value ?? false,
      onChanged: (value) =>
          ref.read(analyticsConsentProvider.notifier).change(value ?? false),
      title: const Text('Share anonymous usage statistics'),
      subtitle: const Text(
        'Optional. No GPS coordinates, contact details or search text.',
      ),
    );
  }
}

class _HomeMap extends ConsumerWidget {
  const _HomeMap();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(searchQueryProvider);
    return StopMap(
      stops: [query.from, query.to],
      height: MediaQuery.sizeOf(context).height < 650 ? 94 : 154,
      onStop: (s) => showBoard(context, ref, s),
      onLocate: () => openScreen(context, 'Nearby stops', const NearbyPage()),
    );
  }
}
