import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/widgets/async_status.dart';
import '../../../../core/widgets/page_heading.dart';
import '../../../timetables/presentation/providers/timetable_providers.dart';
import '../../../timetables/presentation/widgets/service_card.dart';
import '../providers/search_providers.dart';
import '../widgets/search_panel.dart';

class PassengerPage extends StatelessWidget {
  const PassengerPage({super.key});
  @override
  Widget build(BuildContext context) => Center(child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 860),
    child: CustomScrollView(key: const PageStorageKey('passenger'), slivers: [
      const SliverPadding(padding: EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverToBoxAdapter(child: Column(children: [
          PageHeading(title: 'Find your next bus',
            subtitle: 'Search Kerala bus routes, departure times and stop sequences.'),
          SearchPanel(), SizedBox(height: 20),
        ]))),
      const SliverPadding(padding: EdgeInsets.fromLTRB(16, 0, 16, 40),
        sliver: DeparturesSliver()),
    ]),
  ));
}

class DeparturesSliver extends ConsumerWidget {
  const DeparturesSliver({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(departureResultsProvider);
    final query = ref.watch(debouncedSearchProvider);
    return result.when(
      loading: () => const SliverToBoxAdapter(child: AsyncStatus(loading: true)),
      error: (error, stack) => SliverToBoxAdapter(child: AsyncStatus(
        message: 'Unable to load timetables. Check your connection and try again.',
        retry: () => ref.invalidate(publishedServicesProvider))),
      data: (services) => SliverList(delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index == 0) return Padding(padding: const EdgeInsets.only(bottom: 12),
            child: Text('${services.length} buses', style: Theme.of(context).textTheme.titleMedium));
          if (services.isEmpty) return const AsyncStatus(
            message: 'No published buses match these stops and operating days.');
          final service = services[index - 1];
          return ServiceCard(key: ValueKey(service.id), service: service,
            from: query.from, to: query.to, day: query.filterDay);
        },
        childCount: services.isEmpty ? 2 : services.length + 1,
      )),
    );
  }
}
