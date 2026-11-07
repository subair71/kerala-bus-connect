import '../../../../core/widgets/loading_skeletons.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/widgets/editor_sheet.dart';
import '../../../timetables/domain/entities/business_entity.dart';
import '../../../timetables/domain/entities/service_entity.dart';
import '../../../timetables/presentation/providers/timetable_providers.dart';
import '../../domain/entities/trip_plan.dart';
import '../providers/trip_providers.dart';
import 'daily_delay_editor.dart';
import 'trip_editor.dart';

/// Sliver content shares the owner's viewport, so off-screen trips stay unbuilt.
class BusTripDashboard extends ConsumerWidget {
  final BusinessEntity business;
  const BusTripDashboard({super.key, required this.business});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buses = ref.watch(ownerBusesProvider(business.id));
    final selected = ref.watch(selectedBusProvider(business.id));
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(child: _BusHeader(business: business)),
        buses.when(
          loading: () =>
              const LoadingSliver(layout: SkeletonLayout.buses, count: 1, label: 'Loading buses'),
          error: (_, _) => SliverToBoxAdapter(
            child: Column(
              children: [
                const Text('Unable to load your buses.'),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(ownerBusesProvider(business.id)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (list) {
            if (list.isEmpty) {
              return const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Add your first bus, then create its trips.'),
                ),
              );
            }
            final bus =
                list.where((b) => b.id == selected).firstOrNull ?? list.first;
            return SliverMainAxisGroup(
              slivers: [
                SliverToBoxAdapter(
                  child: _BusControls(
                    business: business,
                    bus: bus,
                    buses: list,
                  ),
                ),
                _BusTrips(key: ValueKey(bus.id), business: business, bus: bus),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _BusHeader extends ConsumerWidget {
  final BusinessEntity business;
  const _BusHeader({required this.business});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final action = ref.watch(tripActionsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Buses & trips', style: Theme.of(context).textTheme.headlineSmall),
        const Text(
          'Select bus → Manage trips → Route & stops → Timings → Review',
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: action.isLoading
              ? null
              : () => openEditor(context, _BusEditor(business: business)),
          icon: const Icon(Icons.add),
          label: const Text('Add bus'),
        ),
        if (action.hasError)
          Text(
            action.error.toString(),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    );
  }
}

class _BusControls extends ConsumerWidget {
  final BusinessEntity business;
  final BusEntity bus;
  final List<BusEntity> buses;
  const _BusControls({
    required this.business,
    required this.bus,
    required this.buses,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(
      tripActionsProvider.select((value) => value.isLoading),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey('select-${bus.id}'),
          initialValue: bus.id,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Select bus'),
          items: [
            for (final item in buses)
              DropdownMenuItem(
                value: item.id,
                child: Text(item.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: busy
              ? null
              : (id) {
                  if (id != null)
                    ref
                        .read(selectedBusProvider(business.id).notifier)
                        .select(id);
                },
        ),
        Wrap(
          spacing: 8,
          children: [
            TextButton(
              onPressed: busy
                  ? null
                  : () => openEditor(
                      context,
                      _BusEditor(business: business, bus: bus),
                    ),
              child: const Text('Rename bus'),
            ),
            TextButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (await confirmDelete(context, bus.name) &&
                          context.mounted) {
                        await ref
                            .read(tripActionsProvider.notifier)
                            .deleteBus(bus);
                      }
                    },
              child: ActionShimmer(loading: busy, label: 'Delete bus', child: const Text('Delete bus')),
            ),
          ],
        ),
        FilledButton.tonalIcon(
          onPressed: busy
              ? null
              : () => openEditor(
                  context,
                  TripEditor(
                    business: business,
                    bus: bus,
                    initial: TripPlan(
                      stops: const [
                        TripStop('origin', '', -1),
                        TripStop('destination', '', -1),
                      ],
                    ),
                  ),
                ),
          icon: const Icon(Icons.add_road),
          label: const Text('Create trip'),
        ),
      ],
    );
  }
}

class _BusTrips extends ConsumerWidget {
  final BusinessEntity business;
  final BusEntity bus;
  const _BusTrips({super.key, required this.business, required this.bus});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(
      busTripsProvider((
        ownerId: bus.ownerId,
        businessId: business.id,
        busId: bus.id,
      )),
    );
    return SliverMainAxisGroup(
      slivers: [
        const SliverToBoxAdapter(child: _OperationDateHeader()),
        services.when(
          loading: () =>
              const LoadingSliver(layout: SkeletonLayout.trips, label: 'Loading trips'),
          error: (_, _) => SliverToBoxAdapter(
            child: TextButton(
              onPressed: () => ref.invalidate(ownerServicesProvider),
              child: const Text('Unable to load trips · Retry'),
            ),
          ),
          data: (data) => SliverMainAxisGroup(
            slivers: [
              if (data.trips.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No trips for this bus yet. Create a trip above.',
                    ),
                  ),
                ),
              SliverList.builder(
                itemCount: data.trips.length,
                itemBuilder: (context, i) => _TripCard(
                  key: ValueKey(data.trips[i].id),
                  service: data.trips[i],
                  business: business,
                  bus: bus,
                ),
              ),
              if (data.legacy.isNotEmpty)
                _LegacyTrips(
                  business: business,
                  bus: bus,
                  services: data.legacy,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OperationDateHeader extends ConsumerWidget {
  const _OperationDateHeader();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = ref.watch(operationDateProvider);
    final dateKey = serviceDateKey(date);
    final busy = ref.watch(
      tripActionsProvider.select((value) => value.isLoading),
    );
    final status = ref.watch(
      dailyAdjustmentsProvider(
        dateKey,
      ).select((value) => (loading: value.isLoading, error: value.hasError)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: busy
              ? null
              : () async {
                  final selected = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (selected != null && context.mounted) {
                    ref.read(operationDateProvider.notifier).select(selected);
                  }
                },
          icon: const Icon(Icons.calendar_month),
          label: Text('Service date: $dateKey'),
        ),
        const Text(
          'The date applies to daily delays. Trips below are regular schedules.',
        ),
        SizedBox(
          height: 20,
          child: status.loading
              ? const AppShimmer(label: 'Loading daily updates', child: SkeletonText(fraction: .6, height: 12))
              : null,
        ),
        if (status.error)
          TextButton(
            onPressed: () => ref.invalidate(dailyAdjustmentsProvider(dateKey)),
            child: const Text('Daily updates unavailable · Retry'),
          ),
      ],
    );
  }
}

class _LegacyTrips extends ConsumerWidget {
  final BusinessEntity business;
  final BusEntity bus;
  final List<ServiceEntity> services;
  const _LegacyTrips({
    required this.business,
    required this.bus,
    required this.services,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(legacyTripsExpandedProvider(business.id));
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: ListTile(
            title: const Text('Assign existing timetables'),
            subtitle: const Text(
              'Select a timetable to associate with this bus.',
            ),
            trailing: Icon(expanded ? Icons.expand_less : Icons.expand_more),
            onTap: () => ref
                .read(legacyTripsExpandedProvider(business.id).notifier)
                .toggle(),
          ),
        ),
        if (expanded)
          SliverList.builder(
            itemCount: services.length,
            itemBuilder: (context, i) => Consumer(
              key: ValueKey(services[i].id),
              builder: (context, ref, _) {
                final service = services[i];
                final busy = ref.watch(
                  tripActionsProvider.select((value) => value.isLoading),
                );
                return ListTile(
                  title: Text('${service.busName} · ${service.routeName}'),
                  subtitle: Text(tripTimeLabel(service.departureMinutes)),
                  trailing: IconButton(
                    tooltip: 'Assign and edit',
                    icon: const Icon(Icons.edit),
                    onPressed: busy
                        ? null
                        : () => openEditor(
                            context,
                            TripEditor(
                              business: business,
                              bus: bus,
                              initial: TripPlan.fromService(service),
                            ),
                          ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _TripCard extends ConsumerWidget {
  final BusinessEntity business;
  final BusEntity bus;
  final ServiceEntity service;
  const _TripCard({
    super.key,
    required this.business,
    required this.bus,
    required this.service,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(
      tripActionsProvider.select((value) => value.isLoading),
    );
    final date = ref.watch(operationDateProvider.select(serviceDateKey));
    final daily = ref.watch(
      dailyAdjustmentIndexProvider(date).select(
        (value) => (
          ready: value.hasValue && !value.hasError && !value.isLoading,
          adjustment: value.asData?.value[service.id],
        ),
      ),
    );
    final dailyReady = daily.ready;
    final adjustment = daily.adjustment;
    final trip = TripPlan.fromService(service);
    final updated =
        adjustment != null &&
        adjustment.scheduleRevision == trip.revision &&
        adjustment.delays.values.any((value) => value > 0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              service.routeName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              '${tripTimeLabel(service.departureMinutes)} · ${service.stops.length} stops',
            ),
            Text(service.stops.join(' → ')),
            if (updated) Text('Daily delays saved for $date'),
            if (adjustment != null &&
                adjustment.scheduleRevision != trip.revision)
              const Text('Schedule changed · review this date’s delays'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: busy
                      ? null
                      : () => openEditor(
                          context,
                          TripEditor(
                            business: business,
                            bus: bus,
                            initial: trip,
                          ),
                        ),
                  child: const Text('Edit trip'),
                ),
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () async {
                          final departure = await pickTripTime(
                            context,
                            service.departureMinutes,
                            helpText: 'Set return departure time',
                          );
                          if (departure == null || !context.mounted) return;
                          try {
                            final returning = trip.returnTrip(departure);
                            await openEditor(
                              context,
                              TripEditor(
                                business: business,
                                bus: bus,
                                initial: returning,
                              ),
                            );
                          } catch (error) {
                            if (context.mounted)
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(error.toString())),
                              );
                          }
                        },
                  child: const Text('Create return trip'),
                ),
                OutlinedButton(
                  onPressed: busy || !dailyReady
                      ? null
                      : () => openEditor(
                          context,
                          DailyDelayEditor(
                            bus: bus,
                            trip: trip,
                            date: date,
                            initial: adjustment,
                          ),
                        ),
                  child: const Text('Daily delays'),
                ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () async {
                          if (await confirmDelete(context, service.routeName) &&
                              context.mounted) {
                            await ref
                                .read(tripActionsProvider.notifier)
                                .deleteTrip(bus, trip);
                          }
                        },
                  child: ActionShimmer(loading: busy, label: 'Delete trip', child: const Text('Delete trip')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BusEditor extends HookConsumerWidget {
  final BusinessEntity business;
  final BusEntity? bus;
  const _BusEditor({required this.business, this.bus});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = useTextEditingController(text: bus?.name ?? '');
    final action = ref.watch(tripActionsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EditorHeading(
          title: bus == null ? 'Add bus' : 'Rename bus',
          icon: Icons.directions_bus,
        ),
        TextField(
          controller: name,
          enabled: !action.isLoading,
          decoration: const InputDecoration(
            labelText: 'Bus name or registration',
          ),
        ),
        if (action.hasError) Text(action.error.toString()),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: action.isLoading
              ? null
              : () async {
                  final saved = await ref
                      .read(tripActionsProvider.notifier)
                      .saveBus(business, name.text, bus: bus);
                  if (saved && context.mounted) Navigator.pop(context);
                },
          child: ActionShimmer(loading: action.isLoading, label: 'Save bus', child: const Text('Save bus')),
        ),
      ],
    );
  }
}
