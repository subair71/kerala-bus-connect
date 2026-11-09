import '../../../timetables/domain/entities/service_entity.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/widgets/editor_sheet.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/trip_plan.dart';
import '../providers/trip_providers.dart';
import 'trip_editor.dart';

class DailyDelayEditor extends ConsumerWidget {
  final BusEntity bus;
  final TripPlan trip;
  final String date;
  final DailyAdjustment? initial;
  const DailyDelayEditor({
    super.key,
    required this.bus,
    required this.trip,
    required this.date,
    this.initial,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(ownerIdProvider) != bus.ownerId) {
      return const Text('Please sign in to the bus owner account.');
    }
    final args = (trip: trip, adjustment: initial, date: date);
    final delays = ref.watch(delayDraftProvider(args));
    final status = ref.watch(runningStatusDraftProvider(args));
    final controller = ref.read(delayDraftProvider(args).notifier);
    final action = ref.watch(tripActionsProvider);
    List<int> expected;
    try {
      expected = trip.expectedTimes(delays);
    } catch (error) {
      return Text('Edit the regular timetable first: $error');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EditorHeading(
          title: 'Daily delays',
          icon: Icons.more_time,
          subtitle: '${bus.name} · $date',
        ),
        const Text(
          'Service date = the day this trip starts, including stops after midnight. '
          'Delays affect this date only. Set 0 or remove a delay to clear it.',
        ),
        if (initial != null && initial!.scheduleRevision != trip.revision)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'The regular schedule changed. Previous delays are no longer applied. '
              'Review and enter any delays for this schedule.',
            ),
          ),
        DropdownButtonFormField<RunningStatus>(
          initialValue: status,
          decoration: const InputDecoration(
            labelText: 'Running status (owner reported)',
          ),
          items: [
            for (final value in RunningStatus.values)
              DropdownMenuItem(value: value, child: Text(value.label)),
          ],
          onChanged: action.isLoading
              ? null
              : (value) {
                  if (value == null) return;
                  ref
                      .read(runningStatusDraftProvider(args).notifier)
                      .select(value);
                  if (value != RunningStatus.delayed) controller.reset();
                },
        ),
        const SizedBox(height: 12),
        if (action.hasError)
          Text(
            action.error.toString(),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        for (var i = 0; i < trip.stops.length; i++)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${i + 1}. ${trip.stops[i].name}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text('Scheduled: ${tripTimeLabel(trip.stops[i].minutes)}'),
                  Text(
                    'Expected: ${tripTimeLabel(expected[i])}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (expected[i] != trip.stops[i].minutes)
                    Text(
                      '+${expected[i] - trip.stops[i].minutes} min total delay',
                    ),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: action.isLoading
                            ? null
                            : () async {
                                final value = await showDialog<int>(
                                  context: context,
                                  builder: (_) => _DelayPrompt(
                                    name: trip.stops[i].name,
                                    initial: delays[trip.stops[i].id] ?? 0,
                                  ),
                                );
                                if (value != null && context.mounted) {
                                  controller.setDelay(trip.stops[i].id, value);
                                  if (value > 0)
                                    ref
                                        .read(
                                          runningStatusDraftProvider(
                                            args,
                                          ).notifier,
                                        )
                                        .select(RunningStatus.delayed);
                                }
                              },
                        icon: const Icon(Icons.more_time),
                        label: Text(
                          delays.containsKey(trip.stops[i].id)
                              ? 'Edit delay (+${delays[trip.stops[i].id]} min)'
                              : 'Set delay',
                        ),
                      ),
                      if (delays.containsKey(trip.stops[i].id))
                        TextButton(
                          onPressed: action.isLoading
                              ? null
                              : () => controller.setDelay(trip.stops[i].id, 0),
                          child: const Text('Remove delay'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        const Text(
          'Review the expected times above. Saving replaces the delays for this date.',
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: action.isLoading
              ? null
              : () async {
                  final saved = await ref
                      .read(tripActionsProvider.notifier)
                      .saveDelay(
                        bus,
                        trip,
                        DailyAdjustment(
                          tripId: trip.id,
                          serviceDate: date,
                          scheduleRevision: trip.revision,
                          delays: delays,
                          status: status,
                        ),
                      );
                  if (saved && context.mounted) Navigator.pop(context);
                },
          child: ActionShimmer(
            loading: action.isLoading,
            label: 'Save daily adjustments',
            child: const Text('Save daily adjustments'),
          ),
        ),
        OutlinedButton(
          onPressed: action.isLoading
              ? null
              : () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Reset this date?'),
                      content: Text(
                        'Remove all daily delays for $date and restore the regular timetable.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Reset'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true && context.mounted) {
                    final saved = await ref
                        .read(tripActionsProvider.notifier)
                        .resetDelay(bus, trip, date);
                    if (saved && context.mounted) Navigator.pop(context);
                  }
                },
          child: ActionShimmer(
            loading: action.isLoading,
            label: 'Reset daily adjustments',
            child: const Text('Reset daily adjustments'),
          ),
        ),
        TextButton(
          onPressed: action.isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _DelayPrompt extends HookWidget {
  final String name;
  final int initial;
  const _DelayPrompt({required this.name, required this.initial});
  @override
  Widget build(BuildContext context) {
    final controller = useTextEditingController(text: '$initial');
    final form = useMemoized(() => GlobalKey<FormState>());
    return AlertDialog(
      title: const Text('Set delay'),
      content: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('$name and all following stops'),
            const SizedBox(height: 12),
            TextFormField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Additional delay (minutes)',
              ),
              validator: (text) {
                final value = int.tryParse(text?.trim() ?? '');
                return value == null || value < 0 || value > 1440
                    ? 'Enter a whole number from 0 to 1440.'
                    : null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (form.currentState!.validate())
              Navigator.pop(context, int.parse(controller.text.trim()));
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
