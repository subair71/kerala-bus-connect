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
              SearchPanel(onSearch: mobile ? openResults : null),
              const SizedBox(height: 12),
              const Text(
                'Bus schedules across Kerala',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              const SponsoredCarousel(),
            ],
          );
          if (mobile) {
            return CustomScrollView(
              key: const PageStorageKey('passenger-home'),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Bus schedules across Kerala',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 12),
                          SponsoredCarousel(),
                        ],
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
    final first = ref.watch(departureResultsProvider).asData?.value.firstOrNull;
    final query = ref.watch(debouncedSearchProvider);
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
