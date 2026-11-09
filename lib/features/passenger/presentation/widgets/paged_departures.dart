import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/widgets/loading_skeletons.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../../../timetables/presentation/widgets/service_card.dart';
import '../providers/paged_search_provider.dart';

class PagedDeparturesSliver extends ConsumerWidget {
  final DepartureQuery query;
  const PagedDeparturesSliver({super.key, required this.query});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(pagedDeparturesProvider(query));
    return result.when(
      loading: () => const LoadingSliver(
        layout: SkeletonLayout.departures,
        count: 4,
        label: 'Loading bus results',
      ),
      error: (_, _) => SliverToBoxAdapter(
        child: TextButton(
          onPressed: () => ref.invalidate(pagedDeparturesProvider(query)),
          child: const Text('Unable to load timetables · Retry'),
        ),
      ),
      data: (page) => SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      query.directory ? 'Published routes' : 'Upcoming buses',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh timetables',
                    onPressed: () => ref
                        .read(pagedDeparturesProvider(query).notifier)
                        .refresh(),
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
          ),
          if (page.cached || page.error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  page.error ??
                      'Saved timetable · May be outdated. Daily running updates unavailable offline.',
                ),
              ),
            ),
          SliverList.builder(
            itemCount: page.records.length,
            itemBuilder: (context, i) => ServiceCard(
              key: ValueKey(
                '${page.records[i].id}:${page.records[i].serviceDate}',
              ),
              service: page.records[i],
              from: query.directory ? '' : query.from,
              to: query.to,
              compact: true,
            ),
          ),
          if (page.records.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  page.cursor != null
                      ? 'Continue searching for matching buses.'
                      : 'No upcoming buses match these stops.',
                ),
              ),
            ),
          if (page.cursor != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: OutlinedButton(
                  onPressed: page.loadingMore
                      ? null
                      : () => ref
                            .read(pagedDeparturesProvider(query).notifier)
                            .next(),
                  child: ActionShimmer(
                    loading: page.loadingMore,
                    label: 'Load more buses',
                    child: const Text('Load more buses'),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
