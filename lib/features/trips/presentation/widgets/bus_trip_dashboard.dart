import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/utils/time_utils.dart';
import '../../../../core/widgets/editor_sheet.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../timetables/domain/entities/business_entity.dart';
import '../../../timetables/domain/entities/service_entity.dart';
import '../../../timetables/presentation/providers/timetable_providers.dart';
import '../../domain/entities/trip_plan.dart';
import '../providers/trip_providers.dart';
import 'daily_delay_editor.dart';
import 'trip_editor.dart';

final operationDateProvider =
    NotifierProvider.autoDispose<OperationDate, DateTime>(OperationDate.new);

class OperationDate extends Notifier<DateTime> {
  @override
  DateTime build() {
    ref.watch(ownerIdProvider);
    final now = keralaNow();
    return DateTime(now.year, now.month, now.day);
  }

  void select(DateTime date) =>
      state = DateTime(date.year, date.month, date.day);
}

class BusTripDashboard extends ConsumerWidget {
  final BusinessEntity business;
  const BusTripDashboard({super.key, required this.business});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buses = ref.watch(ownerBusesProvider(business.id));
    final selected = ref.watch(selectedBusProvider(business.id));
    final action = ref.watch(tripActionsProvider);
    final busy = action.isLoading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Buses & trips', style: Theme.of(context).textTheme.headlineSmall),
        const Text(
          'Select bus → Manage trips → Route & stops → Timings → Review',
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: busy
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
        buses.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, stack) => Column(
            children: [
              const Text('Unable to load your buses.'),
              TextButton(
                onPressed: () =>
                    ref.invalidate(ownerBusesProvider(business.id)),
                child: const Text('Retry'),
              ),
            ],
          ),
          data: (list) {
            if (list.isEmpty)
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Add your first bus, then create its trips.'),
              );
            final bus =
                list.where((b) => b.id == selected).firstOrNull ?? list.first;
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
                    for (final item in list)
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
                      child: const Text('Delete bus'),
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
                _BusTrips(key: ValueKey(bus.id), business: business, bus: bus),
              ],
            );
          },
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
    final services = ref.watch(ownerServicesProvider);
    final date = ref.watch(operationDateProvider);
    final dateKey = serviceDateKey(date);
    final adjustments = ref.watch(dailyAdjustmentsProvider(dateKey));
    final busy = ref.watch(tripActionsProvider).isLoading;
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
        if (adjustments.isLoading) const LinearProgressIndicator(),
        if (adjustments.hasError)
          TextButton(
            onPressed: () => ref.invalidate(dailyAdjustmentsProvider(dateKey)),
            child: const Text('Daily updates unavailable · Retry'),
          ),
        services.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => TextButton(
            onPressed: () => ref.invalidate(ownerServicesProvider),
            child: const Text('Unable to load trips · Retry'),
          ),
          data: (all) {
            final trips =
                all
                    .where((s) => s.busId == bus.id && s.ownerId == bus.ownerId)
                    .toList()
                  ..sort(
                    (a, b) => a.departureMinutes.compareTo(b.departureMinutes),
                  );
            final legacy = all
                .where(
                  (s) =>
                      s.busId.isEmpty &&
                      s.businessId == business.id &&
                      s.ownerId == bus.ownerId,
                )
                .toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (trips.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No trips for this bus yet. Create a trip above.',
                    ),
                  ),
                for (final service in trips)
                  _TripCard(
                    service: service,
                    business: business,
                    bus: bus,
                    date: dateKey,
                    dailyReady:
                        adjustments.hasValue &&
                        !adjustments.hasError &&
                        !adjustments.isLoading,
                    adjustment: adjustments.asData?.value
                        .where((a) => a.tripId == service.id)
                        .firstOrNull,
                  ),
                if (legacy.isNotEmpty)
                  ExpansionTile(
                    title: const Text('Assign existing timetables'),
                    subtitle: const Text(
                      'Select a timetable to associate with this bus.',
                    ),
                    children: [
                      for (final service in legacy)
                        ListTile(
                          title: Text(
                            '${service.busName} · ${service.routeName}',
                          ),
                          subtitle: Text(
                            tripTimeLabel(service.departureMinutes),
                          ),
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
                        ),
                    ],
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _TripCard extends ConsumerWidget {
  final BusinessEntity business;
  final BusEntity bus;
  final ServiceEntity service;
  final String date;
  final bool dailyReady;
  final DailyAdjustment? adjustment;
  const _TripCard({
    required this.business,
    required this.bus,
    required this.service,
    required this.date,
    required this.dailyReady,
    this.adjustment,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(tripActionsProvider).isLoading;
    final trip = TripPlan.fromService(service);
    final updated =
        adjustment?.scheduleRevision == trip.revision &&
        adjustment!.delays.values.any((value) => value > 0);
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
                adjustment!.scheduleRevision != trip.revision)
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
                  child: const Text('Delete trip'),
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
          child: const Text('Save bus'),
        ),
      ],
    );
  }
}
