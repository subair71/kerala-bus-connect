import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/theme/home_theme.dart';
import '../../../timetables/domain/entities/service_entity.dart';
import '../providers/home_service_providers.dart';
import '../widgets/transit_advisory.dart';
import '../../../../core/widgets/async_status.dart';
import '../../../../core/widgets/data_notice.dart';
import '../../../sponsors/presentation/widgets/sponsored_carousel.dart';
import '../../../timetables/presentation/providers/timetable_providers.dart';
import '../../../timetables/presentation/widgets/service_card.dart';
import '../../../timetables/presentation/widgets/train_route_view.dart';
import '../providers/search_providers.dart';
import '../widgets/search_panel.dart';

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
          const top = Column(children: [SearchPanel(), SponsoredCarousel()]);
          final results = CustomScrollView(
            key: const PageStorageKey('passenger'),
            slivers: [
              if (!wide)
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
                  sliver: SliverToBoxAdapter(child: top),
                ),
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                sliver: SliverToBoxAdapter(child: _CatalogNotice()),
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
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: SearchPanel(),
              ),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 2, child: results),
                    const Expanded(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(8, 12, 16, 24),
                        child: Column(
                          children: [
                            SponsoredCarousel(),
                            Expanded(child: _TimelinePreview()),
                          ],
                        ),
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

class _CatalogNotice extends ConsumerWidget {
  const _CatalogNotice();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(serviceCatalogProvider).asData?.value;
    if (!(data?.unavailable ?? false)) return const SizedBox.shrink();
    return DataNotice(
      demo: data?.isDemo ?? false,
      unavailable: data?.unavailable ?? false,
      retry: () => ref.invalidate(publishedServicesProvider),
    );
  }
}

class DeparturesSliver extends ConsumerWidget {
  const DeparturesSliver({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(departureResultsProvider);
    final query = ref.watch(debouncedSearchProvider);
    return result.when(
      loading: () =>
          const SliverToBoxAdapter(child: AsyncStatus(loading: true)),
      error: (_, _) => SliverToBoxAdapter(
        child: AsyncStatus(
          message: 'Unable to load timetables.',
          retry: () => ref.invalidate(publishedServicesProvider),
        ),
      ),
      data: (services) => SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          if (index == 0)
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '${services.length} buses found',
                        style: const TextStyle(
                          fontSize: 22,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -.6,
                          color: HomeTheme.text,
                        ),
                      ),
                      if (query.from.trim().isNotEmpty)
                        Text(
                          'from ${query.from}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: HomeTheme.muted,
                          ),
                        ),
                    ],
                  ),
                  Tooltip(
                    message: 'Sorted by earliest scheduled departure',
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.sort, size: 15, color: HomeTheme.primary),
                          SizedBox(width: 6),
                          Text(
                            'Earliest first',
                            style: TextStyle(
                              fontSize: 11,
                              color: HomeTheme.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          if (services.isEmpty)
            return const AsyncStatus(
              message:
                  'No published buses match these stops and operating days.',
            );
          final service = services[index - 1];
          return _HomeDepartureCard(
            key: ValueKey(service.id),
            service: service,
            from: query.from,
            to: query.to,
            day: query.filterDay,
          );
        }, childCount: services.isEmpty ? 2 : services.length + 1),
      ),
    );
  }
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

class _HomeDepartureCard extends ConsumerWidget {
  final ServiceEntity service;
  final String from, to, day;
  const _HomeDepartureCard({
    super.key,
    required this.service,
    required this.from,
    required this.to,
    required this.day,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = ref.watch(homeServiceDetailsProvider(service.id));
    return ServiceCard(
      service: service,
      from: from,
      to: to,
      day: day,
      compact: true,
      demoFare: details.fareRupees,
      demoFareLabel: details.fareLabel,
    );
  }
}
