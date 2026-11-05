import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/theme/home_theme.dart';
import '../../../../core/widgets/async_status.dart';
import '../../../../core/widgets/data_notice.dart';
import '../../../timetables/domain/entities/service_entity.dart';
import '../../../timetables/presentation/providers/timetable_providers.dart';
import '../../../timetables/presentation/widgets/service_card.dart';
import '../providers/home_service_providers.dart';
import '../providers/search_providers.dart';

class CatalogNotice extends ConsumerWidget {
  const CatalogNotice();
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
                          Flexible(
                            child: Text(
                              'Earliest first',
                              style: TextStyle(
                                fontSize: 11,
                                color: HomeTheme.text,
                              ),
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
