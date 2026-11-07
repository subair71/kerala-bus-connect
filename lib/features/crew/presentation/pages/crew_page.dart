import '../../../../core/widgets/loading_skeletons.dart';
import '../../../../core/widgets/data_notice.dart';
import '../../../../core/widgets/async_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/widgets/page_heading.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/widgets/app_components.dart';
import '../providers/crew_providers.dart';

class CrewPage extends StatelessWidget {
  const CrewPage({super.key});
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 860),
      child: const CustomScrollView(
        key: PageStorageKey('crew'),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverPadding(
            padding: EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(child: _CrewHeader()),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: _CrewList(),
          ),
        ],
      ),
    ),
  );
}

class _CrewHeader extends HookConsumerWidget {
  const _CrewHeader();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = useTextEditingController(
      text: ref.read(crewFilterProvider).query,
    );
    final shift = ref.watch(
      crewFilterProvider.select((filter) => filter.shift),
    );
    final data = ref.watch(
      crewDataProvider.select(
        (value) => (
          demo: value.asData?.value.isDemo ?? false,
          unavailable: value.asData?.value.unavailable ?? false,
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHeading(
          title: 'Crew duty roster',
          subtitle: 'Assignments, vehicles and operating shifts.',
        ),
        DataNotice(
          demo: data.demo,
          unavailable: data.unavailable,
          retry: () => ref.invalidate(liveCrewProvider),
        ),
        TextField(
          controller: controller,
          onChanged: ref.read(crewFilterProvider.notifier).search,
          decoration: const InputDecoration(
            labelText: 'Search crew or vehicle',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final value in ['All', 'Morning', 'Evening', 'Standby'])
              ChoiceChip(
                label: Text(value),
                selected: value == shift,
                onSelected: (_) =>
                    ref.read(crewFilterProvider.notifier).shift(value),
              ),
          ],
        ),
      ],
    );
  }
}

class _CrewList extends ConsumerWidget {
  const _CrewList();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(crewDataProvider);
    if (data.isLoading && !data.hasValue) {
      return const LoadingSliver(
        layout: SkeletonLayout.crew,
        label: 'Loading crew assignments',
      );
    }
    if (data.hasError) {
      return SliverToBoxAdapter(
        child: AsyncStatus(
          message: 'Unable to load crew assignments.',
          retry: () => ref.invalidate(liveCrewProvider),
        ),
      );
    }
    final crew = ref.watch(filteredCrewProvider);
    if (crew.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No matching assignments.'),
        ),
      );
    }
    return SliverList.builder(
      itemCount: crew.length,
      itemBuilder: (context, index) {
        final person = crew[index];
        return Card(
          key: ValueKey(person.id.isEmpty ? index : person.id),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppIconTile(Icons.badge_outlined),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        person.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${person.role} • ${person.vehicle}',
                        style: const TextStyle(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          AppStatusBadge(
                            label: person.shift,
                            foreground: AppColors.onSurfaceVariant,
                            background: AppColors.surfaceLow,
                          ),
                          Text(
                            person.duty,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
