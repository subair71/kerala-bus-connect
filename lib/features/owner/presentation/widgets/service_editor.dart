import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/constants/transit_constants.dart';
import '../../../../core/utils/time_utils.dart';
import '../../../timetables/domain/entities/business_entity.dart';
import '../../../timetables/domain/entities/route_entity.dart';
import '../../../timetables/domain/entities/service_entity.dart';
import '../providers/owner_providers.dart';

class ServiceEditor extends HookConsumerWidget {
  final BusinessEntity business;
  final RouteEntity route;
  final ServiceEntity? service;
  const ServiceEditor({super.key, required this.business, required this.route, this.service});

  Future<void> _pick(BuildContext context, int minutes, void Function(int) update) async {
    final time = await showTimePicker(context: context,
      initialTime: TimeOfDay(hour: (minutes ~/ 60) % 24, minute: minutes % 60));
    if (time != null && context.mounted) update(time.hour * 60 + time.minute);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = useTextEditingController(text: service?.busName ?? '');
    final note = useTextEditingController(text: service?.offTimingsNote ?? '');
    final args = (route: route, service: service);
    final draft = ref.watch(serviceDraftProvider(args));
    final draftController = ref.read(serviceDraftProvider(args).notifier);
    final action = ref.watch(ownerActionsProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(service == null ? 'Publish timetable' : 'Edit timetable', style: Theme.of(context).textTheme.headlineSmall),
      Text(route.name),
      const SizedBox(height: 16),
      TextField(key: const ValueKey('bus-name'), controller: name,
        decoration: const InputDecoration(labelText: 'Bus name / registration number')),
      const SizedBox(height: 12),
      ListTile(contentPadding: EdgeInsets.zero, title: const Text('Departure'),
        subtitle: const Text('Changing departure resets stops to 15-minute intervals.'),
        trailing: Text(timeLabel(draft.departure)),
        onTap: () => _pick(context, draft.departure, draftController.departure)),
      const Divider(),
      const Text('Stop timings', style: TextStyle(fontWeight: FontWeight.w700)),
      for (final stop in route.stops) ListTile(contentPadding: EdgeInsets.zero,
        title: Text(stop), trailing: Text(timeLabel(draft.timings[stop] ?? draft.departure)),
        onTap: () => _pick(context, draft.timings[stop] ?? draft.departure,
          (minutes) => draftController.stopTime(stop, minutes))),
      const SizedBox(height: 12),
      const Text('Days without service', style: TextStyle(fontWeight: FontWeight.w700)),
      Wrap(spacing: 8, children: [
        for (final day in weekDays) FilterChip(label: Text(day),
          selected: draft.offDays.contains(day), onSelected: (_) => draftController.toggleDay(day)),
      ]),
      const SizedBox(height: 12),
      TextField(controller: note, minLines: 1, maxLines: 3,
        decoration: const InputDecoration(labelText: 'Off-timing / bypass notes (optional)')),
      if (action.hasError) Padding(padding: const EdgeInsets.only(top: 12),
        child: Text(action.error.toString(), style: TextStyle(color: Theme.of(context).colorScheme.error))),
      const SizedBox(height: 16),
      FilledButton(onPressed: action.isLoading ? null : () async {
        final saved = await ref.read(ownerActionsProvider.notifier).saveService(
          business: business, route: route, busName: name.text, draft: draft, note: note.text, id: service?.id);
        if (saved && context.mounted) Navigator.pop(context);
      }, child: Text(action.isLoading ? 'Saving…' : service == null ? 'Publish timetable' : 'Save timetable')),
    ]);
  }
}
