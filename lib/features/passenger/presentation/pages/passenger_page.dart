import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/constants/colors.dart';
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
              constraints.maxWidth >= 1050 && constraints.maxHeight >= 760 &&
              MediaQuery.textScalerOf(context).scale(14) <= 18;
          const top = Column(children: [SearchPanel(), SponsoredCarousel()]);
          final results = CustomScrollView(
            key: const PageStorageKey('passenger'),
            slivers: [
              if (!wide)
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 20, 16, 0),
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
                sliver: SliverToBoxAdapter(child: _ScheduleNote()),
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
                spacing: 12,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '${services.length} buses found',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Text(
                    'Sorted by earliest departure',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.onSurfaceVariant,
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
          return ServiceCard(
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

class _ScheduleNote extends StatelessWidget {
  const _ScheduleNote();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surfaceLow,
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.schedule, size: 18, color: AppColors.onSurfaceVariant),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Timetable estimates are scheduled departures, not live GPS tracking. Traffic and route changes may affect actual arrival times.',
            style: TextStyle(
              fontSize: 12,
              height: 1.6,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    ),
  );
}
