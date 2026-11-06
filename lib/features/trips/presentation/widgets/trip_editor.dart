import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/constants/transit_constants.dart';
import '../../../../core/utils/time_utils.dart';
import '../../../../core/widgets/editor_sheet.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../timetables/domain/entities/business_entity.dart';
import '../../domain/entities/trip_plan.dart';
import '../providers/trip_providers.dart';

String tripTimeLabel(int minutes) {
  if (minutes < 0) return 'Set time';
  final day = minutes ~/ 1440;
  return '${timeLabel(minutes)}${day == 1 ? ' · Next day' : day > 1 ? ' · Day +$day' : ''}';
}

Future<int?> pickTripTime(BuildContext context, int minutes, {String? helpText}) async {
  final time = await showTimePicker(
    context: context,
    helpText: helpText,
    initialTime: TimeOfDay(hour: minutes < 0 ? 8 : minutes % 1440 ~/ 60,
      minute: minutes < 0 ? 0 : minutes % 60),
    initialEntryMode: TimePickerEntryMode.input,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
      child: child!,
    ),
  );
  return time == null ? null : time.hour * 60 + time.minute;
}

class TripEditor extends ConsumerWidget {
  final BusinessEntity business;
  final BusEntity bus;
  final TripPlan initial;
  const TripEditor({super.key, required this.business,
    required this.bus, required this.initial});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owner = ref.watch(ownerIdProvider);
    if (owner != bus.ownerId) return const Text('Please sign in to the bus owner account.');
    final args = (plan: initial, ownerId: owner!);
    final state = ref.watch(tripDraftProvider(args));
    final controller = ref.read(tripDraftProvider(args).notifier);
    final action = ref.watch(tripActionsProvider);
    final plan = state.plan;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EditorHeading(title: initial.id.isEmpty ? 'New trip' : 'Edit trip',
          icon: Icons.route, subtitle: bus.name),
        const Text('Regular timetable · changes apply to future service dates. '
          'Use Daily delays for one day’s operational changes.'),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (var i = 0; i < 3; i++)
            ChoiceChip(
              label: Text(['1. Route & stops', '2. Timings', '3. Review'][i]),
              selected: state.step == i,
              onSelected: action.isLoading ? null : (_) => controller.step(i),
            ),
        ]),
        const SizedBox(height: 16),
        if (state.error != null)
          Text(state.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (action.hasError)
          Text(action.error.toString(), style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (state.step == 0) ...[
          const Text('First stop = origin · Last stop = destination. '
            'Drag the handle or use Move up / Move down. Recheck timings after reordering.'),
          ReorderableListView.builder(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false, itemCount: plan.stops.length,
            onReorderItem: (from, to) {
              if (!action.isLoading) controller.move(from, to);
            },
            itemBuilder: (context, index) {
              final stop = plan.stops[index];
              return Card(
                key: ValueKey(stop.id),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        ReorderableDragStartListener(index: index,
                          enabled: !action.isLoading,
                          child: Semantics(label: 'Drag to reorder ${stop.name}',
                            child: const SizedBox(width: 48, height: 48,
                              child: Icon(Icons.drag_handle)))),
                        Expanded(child: _StopName(
                          key: ValueKey('name-${stop.id}'),
                          stop: stop, enabled: !action.isLoading,
                          label: index == 0 ? 'Origin' :
                              index == plan.stops.length - 1 ? 'Destination' : 'Stop ${index + 1}',
                          onChanged: (name) => controller.rename(index, name),
                        )),
                      ]),
                      Wrap(children: [
                        IconButton(tooltip: 'Move up ${stop.name}',
                          onPressed: index == 0 || action.isLoading ? null :
                              () => controller.move(index, index - 1),
                          icon: const Icon(Icons.arrow_upward)),
                        IconButton(tooltip: 'Move down ${stop.name}',
                          onPressed: index == plan.stops.length - 1 || action.isLoading ? null :
                              () => controller.move(index, index + 1),
                          icon: const Icon(Icons.arrow_downward)),
                        IconButton(tooltip: 'Remove ${stop.name}',
                          onPressed: plan.stops.length <= 2 || action.isLoading ? null :
                              () => controller.remove(index),
                          icon: const Icon(Icons.delete_outline)),
                      ]),
                    ]),
                ),
              );
            },
          ),
          OutlinedButton.icon(onPressed: action.isLoading || plan.stops.length >= 100
            ? null : controller.addStop, icon: const Icon(Icons.add),
            label: const Text('Add stop')),
        ] else ...[
          for (var i = 0; i < plan.stops.length; i++)
            _TimelineStop(
              number: i + 1,
              last: i == plan.stops.length - 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(plan.stops[i].name, style: Theme.of(context).textTheme.titleMedium),
                  if (state.step == 1) ...[
                    OutlinedButton.icon(
                      key: ValueKey('time-${plan.stops[i].id}'),
                      onPressed: action.isLoading ? null : () async {
                        final minutes = await pickTripTime(context, plan.stops[i].minutes);
                        if (minutes != null && context.mounted) {
                          final day = i == 0 || plan.stops[i].minutes < 0
                              ? 0 : plan.stops[i].minutes ~/ 1440;
                          controller.time(i, minutes + day * 1440);
                        }
                      },
                      icon: const Icon(Icons.schedule),
                      label: Text(tripTimeLabel(plan.stops[i].minutes)),
                    ),
                    if (i == 0)
                      const Text('Changing departure shifts every configured stop by the same amount.'),
                    if (i > 0)
                      DropdownButtonFormField<int>(
                        isExpanded: true,
                        key: ValueKey('day-${plan.stops[i].id}-${plan.stops[i].minutes ~/ 1440}'),
                        initialValue: plan.stops[i].minutes >= 1440 ? 1 : 0,
                        decoration: const InputDecoration(labelText: 'Day'),
                        items: const [
                          DropdownMenuItem(value: 0, child: Text('Service date')),
                          DropdownMenuItem(value: 1, child: Text('Next day')),
                        ],
                        onChanged: action.isLoading || plan.stops[i].minutes < 0
                            ? null : (day) {
                          if (day != null) controller.time(i,
                            plan.stops[i].minutes % 1440 + day * 1440);
                        },
                      ),
                  ] else Text('Scheduled: ${tripTimeLabel(plan.stops[i].minutes)}'),
                ],
              ),
            ),
          if (state.step == 1) ...[
            const Text('Operating days'),
            Wrap(spacing: 8, children: [
              for (final day in weekDays)
                FilterChip(label: Text(day.substring(0, 3)),
                  selected: !plan.offDays.contains(day),
                  onSelected: action.isLoading ? null : (_) => controller.offDay(day)),
            ]),
            _NoteField(initial: plan.note, onChanged: controller.note),
          ] else ...[
            Text(plan.offDays.isEmpty ? 'Runs every day' : 'Off: ${plan.offDays.join(', ')}'),
            if (plan.note.isNotEmpty) Text(plan.note),
            const SizedBox(height: 12),
            const Text('Review the route and all times before saving. '
              'If a schedule changes, daily delays must be reviewed against the new schedule.'),
          ],
        ],
        const SizedBox(height: 16),
        if (action.isLoading) const LinearProgressIndicator(),
        FilledButton(
          onPressed: action.isLoading ? null : () async {
            if (state.step < 2) {
              controller.step(state.step + 1);
            } else {
              final saved = await ref.read(tripActionsProvider.notifier)
                  .saveTrip(business, bus, plan);
              if (saved && context.mounted) Navigator.pop(context);
            }
          },
          child: Text(state.step == 0 ? 'Continue to timings' :
            state.step == 1 ? 'Review trip' : 'Save trip'),
        ),
        TextButton(onPressed: action.isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel')),
      ],
    );
  }
}

class _StopName extends HookWidget {
  final TripStop stop;
  final String label;
  final bool enabled;
  final ValueChanged<String> onChanged;
  const _StopName({super.key, required this.stop, required this.label,
    required this.enabled, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final controller = useTextEditingController(text: stop.name);
    return TextField(controller: controller, enabled: enabled,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(labelText: label),
      onChanged: onChanged);
  }
}

class _NoteField extends HookWidget {
  final String initial;
  final ValueChanged<String> onChanged;
  const _NoteField({required this.initial, required this.onChanged});
  @override
  Widget build(BuildContext context) => TextField(
    controller: useTextEditingController(text: initial),
    decoration: const InputDecoration(labelText: 'Passenger note (optional)'),
    onChanged: onChanged,
  );
}

class _TimelineStop extends StatelessWidget {
  final int number;
  final bool last;
  final Widget child;
  const _TimelineStop({required this.number, required this.last, required this.child});
  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(width: 40, child: Column(children: [
        CircleAvatar(radius: 14, child: Text('$number')),
        if (!last) Expanded(child: VerticalDivider(
          color: Theme.of(context).colorScheme.primary, thickness: 2)),
      ])),
      Expanded(child: Padding(padding: const EdgeInsets.only(bottom: 24, left: 8),
        child: child)),
    ]),
  );
}
