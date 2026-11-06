import '../../../trips/presentation/widgets/bus_trip_dashboard.dart';
import '../../../../core/utils/sample_ids.dart';
import '../../../../core/widgets/data_notice.dart';
import '../widgets/sample_owner_preview.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/widgets/async_status.dart';
import '../../../../core/widgets/editor_sheet.dart';
import '../../../../core/widgets/page_heading.dart';
import '../../../../core/utils/time_utils.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/widgets/auth_panel.dart';
import '../../../timetables/domain/entities/business_entity.dart';
import '../../../timetables/domain/entities/route_entity.dart';
import '../../../timetables/presentation/providers/timetable_providers.dart';
import '../providers/owner_providers.dart';
import '../widgets/business_editor.dart';
import '../widgets/route_editor.dart';
import '../widgets/service_editor.dart';

class OwnerPage extends ConsumerWidget {
  const OwnerPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(authUserProvider)
      .when(
        loading: () => const Center(child: AsyncStatus(loading: true)),
        error: (_, stack) => AsyncStatus(
          message: 'Unable to check your account.',
          retry: () => ref.invalidate(authUserProvider),
        ),
        data: (user) => user == null
            ? SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: const Column(
                      children: [AuthPanel(), SampleOwnerPreview()],
                    ),
                  ),
                ),
              )
            : _OwnerWorkspace(key: ValueKey(user.id)),
      );
}

class _OwnerWorkspace extends ConsumerWidget {
  const _OwnerWorkspace({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businesses = ref.watch(ownerBusinessesProvider);
    final businessDisplay = ref.watch(ownerBusinessDisplayProvider);
    final selected = ref.watch(selectedBusinessProvider);
    final action = ref.watch(ownerActionsProvider);
    final authAction = ref.watch(authActionProvider);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: CustomScrollView(
          key: const PageStorageKey('owner'),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const PageHeading(
                      title: 'Owner portal',
                      subtitle: 'Manage your buses, trips and daily timings.',
                    ),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: action.isLoading
                              ? null
                              : () =>
                                    openEditor(context, const BusinessEditor()),
                          icon: const Icon(Icons.add_business),
                          label: const Text('Add business'),
                        ),
                        OutlinedButton(
                          onPressed: authAction.isLoading
                              ? null
                              : () => ref
                                    .read(authActionProvider.notifier)
                                    .signOut(),
                          child: const Text('Sign out'),
                        ),
                      ],
                    ),
                    if (action.isLoading || authAction.isLoading)
                      const LinearProgressIndicator(),
                    if (action.hasError || authAction.hasError)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          (action.error ?? authAction.error).toString(),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    if (businesses.hasError)
                      const DataNotice(demo: true, unavailable: true),
                    businesses.when(
                      loading: () => const AsyncStatus(loading: true),
                      error: (_, stack) => AsyncStatus(
                        message: 'Unable to load your businesses.',
                        retry: () => ref.invalidate(ownerBusinessesProvider),
                      ),
                      data: (list) => list.isEmpty
                          ? const AsyncStatus(
                              message:
                                  'Create your first business to add routes.',
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                DropdownButtonFormField<String>(
                                  key: ValueKey(selected?.id),
                                  initialValue: selected?.id,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Business',
                                  ),
                                  items: [
                                    for (final business in list)
                                      DropdownMenuItem(
                                        value: business.id,
                                        child: Text(
                                          business.name,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ],
                                  onChanged: (id) {
                                    if (id != null)
                                      ref
                                          .read(
                                            selectedBusinessIdProvider.notifier,
                                          )
                                          .select(id);
                                  },
                                ),
                                if (selected != null)
                                  Wrap(
                                    spacing: 12,
                                    children: [
                                      TextButton(
                                        onPressed: action.isLoading
                                            ? null
                                            : () => openEditor(
                                                context,
                                                BusinessEditor(
                                                  business: selected,
                                                ),
                                              ),
                                        child: const Text('Rename business'),
                                      ),
                                      FilledButton.tonalIcon(
                                        onPressed: action.isLoading
                                            ? null
                                            : () => openEditor(
                                                context,
                                                RouteEditor(business: selected),
                                              ),
                                        icon: const Icon(Icons.add_road),
                                        label: const Text('Add route'),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                    ),
                    if (businessDisplay.asData?.value.isDemo ?? false)
                      const SampleOwnerPreview(),
                  ],
                ),
              ),
            ),
            if (selected != null) ...[
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(
                  child: BusTripDashboard(business: selected),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: _OwnerRoutes(business: selected),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                sliver: _OwnerServices(business: selected),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OwnerRoutes extends ConsumerWidget {
  final BusinessEntity business;
  const _OwnerRoutes({required this.business});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routes = ref.watch(ownerRoutesDisplayProvider(business.id));
    final busy = ref.watch(
      ownerActionsProvider.select((value) => value.isLoading),
    );
    return routes.when(
      loading: () =>
          const SliverToBoxAdapter(child: AsyncStatus(loading: true)),
      error: (_, stack) => SliverToBoxAdapter(
        child: AsyncStatus(
          message: 'Unable to load routes.',
          retry: () => ref.invalidate(businessRoutesProvider(business.id)),
        ),
      ),
      data: (data) => data.records.isEmpty
          ? const SliverToBoxAdapter(
              child: AsyncStatus(message: 'No routes yet. Add one above.'),
            )
          : SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                if (index == 0)
                  return DataNotice(
                    demo: data.isDemo,
                    unavailable: data.unavailable,
                    retry: () =>
                        ref.invalidate(businessRoutesProvider(business.id)),
                  );
                final route = data.records[index - 1];
                final readOnly = busy || isSampleId(route.id);
                return Card(
                  key: ValueKey(route.id),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (isSampleId(route.id))
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: DemoBadge(),
                          ),
                        Text(
                          route.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(route.stops.join(' → ')),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            TextButton(
                              onPressed: readOnly
                                  ? null
                                  : () => openEditor(
                                      context,
                                      RouteEditor(
                                        business: business,
                                        route: route,
                                      ),
                                    ),
                              child: const Text('Edit route'),
                            ),
                            TextButton(
                              onPressed: readOnly
                                  ? null
                                  : () => ref
                                        .read(ownerActionsProvider.notifier)
                                        .generateReturn(route),
                              child: const Text('Create return'),
                            ),
                            TextButton(
                              onPressed: readOnly
                                  ? null
                                  : () async {
                                      if (await confirmDelete(
                                            context,
                                            route.name,
                                          ) &&
                                          context.mounted) {
                                        await ref
                                            .read(ownerActionsProvider.notifier)
                                            .deleteRoute(route.id);
                                      }
                                    },
                              child: const Text('Delete route'),
                            ),
                            FilledButton.tonal(
                              onPressed: readOnly
                                  ? null
                                  : () => openEditor(
                                      context,
                                      ServiceEditor(
                                        business: business,
                                        route: route,
                                      ),
                                    ),
                              child: const Text('Add timetable'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }, childCount: data.records.length + 1),
            ),
    );
  }
}

class _OwnerServices extends ConsumerWidget {
  final BusinessEntity business;
  const _OwnerServices({required this.business});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(ownerServicesDisplayProvider(business.id));
    final routes =
        ref.watch(businessRoutesProvider(business.id)).asData?.value ??
        const <RouteEntity>[];
    final busy = ref.watch(
      ownerActionsProvider.select((value) => value.isLoading),
    );
    return services.when(
      loading: () =>
          const SliverToBoxAdapter(child: AsyncStatus(loading: true)),
      error: (_, stack) => SliverToBoxAdapter(
        child: AsyncStatus(
          message: 'Unable to load timetables.',
          retry: () => ref.invalidate(ownerServicesProvider),
        ),
      ),
      data: (data) {
        final list = data.records.where((s) => s.busId.isEmpty).toList();
        return SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            if (index == 0)
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DataNotice(
                    demo: data.isDemo,
                    unavailable: data.unavailable,
                    retry: () => ref.invalidate(ownerServicesProvider),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      '${data.isDemo ? 'Sample' : 'Published'} timetables (${list.length})',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              );
            final service = list[index - 1];
            final readOnly = busy || isSampleId(service.id);
            final route = routes
                .where((r) => r.id == service.routeId)
                .firstOrNull;
            return Card(
              key: ValueKey(service.id),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isSampleId(service.id))
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: DemoBadge(),
                      ),
                    Text(
                      service.busName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${service.routeName} • ${service.departureMinutes < 0 ? 'Time unavailable' : timeLabel(service.departureMinutes)}',
                    ),
                    Text(
                      !service.operatingDaysKnown
                          ? 'Operating days unavailable'
                          : service.offDays.isEmpty
                          ? 'Runs every day'
                          : 'Off: ${service.offDays.join(', ')}',
                    ),
                    Wrap(
                      spacing: 12,
                      children: [
                        TextButton(
                          onPressed: readOnly || route == null
                              ? null
                              : () => openEditor(
                                  context,
                                  ServiceEditor(
                                    business: business,
                                    route: route,
                                    service: service,
                                  ),
                                ),
                          child: const Text('Edit timetable'),
                        ),
                        TextButton(
                          onPressed: readOnly
                              ? null
                              : () async {
                                  if (await confirmDelete(
                                        context,
                                        service.busName,
                                      ) &&
                                      context.mounted) {
                                    await ref
                                        .read(ownerActionsProvider.notifier)
                                        .deleteService(service.id);
                                  }
                                },
                          child: const Text('Delete timetable'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }, childCount: list.length + 1),
        );
      },
    );
  }
}
