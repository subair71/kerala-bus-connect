import '../../../../core/widgets/data_notice.dart';
import '../../../../core/widgets/async_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/widgets/page_heading.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/widgets/app_components.dart';
import '../providers/crew_providers.dart';

class CrewPage extends HookConsumerWidget {
  const CrewPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = useTextEditingController(
      text: ref.read(crewFilterProvider).query,
    );
    final shift = ref.watch(
      crewFilterProvider.select((filter) => filter.shift),
    );
    final crew = ref.watch(filteredCrewProvider);
    final data = ref.watch(crewDataProvider);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: crew.length + 1,
          itemBuilder: (context, index) {
            if (index == 0)
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const PageHeading(
                    title: 'Crew duty roster',
                    subtitle: 'Assignments, vehicles and operating shifts.',
                  ),
                  DataNotice(
                    demo: data.asData?.value.isDemo ?? false,
                    unavailable: data.asData?.value.unavailable ?? false,
                    retry: () => ref.invalidate(liveCrewProvider),
                  ),
                  if (data.isLoading) const AsyncStatus(loading: true),
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
                      for (final value in [
                        'All',
                        'Morning',
                        'Evening',
                        'Standby',
                      ])
                        ChoiceChip(
                          label: Text(value),
                          selected: value == shift,
                          onSelected: (_) => ref
                              .read(crewFilterProvider.notifier)
                              .shift(value),
                        ),
                    ],
                  ),
                  if (crew.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No matching assignments.'),
                    ),
                ],
              );
            final person = crew[index - 1];
            return Card(
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
                              AppStatusBadge(label: person.shift,
                                foreground: AppColors.onSurfaceVariant,
                                background: AppColors.surfaceLow),
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
        ),
      ),
    );
  }
}
