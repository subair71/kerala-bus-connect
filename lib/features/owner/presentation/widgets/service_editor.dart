import '../../../../core/widgets/shimmer_loading.dart';
import 'package:flutter/material.dart';
import '../../../../core/widgets/editor_sheet.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/constants/transit_constants.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/utils/time_utils.dart';
import '../../../timetables/domain/entities/business_entity.dart';
import '../../../timetables/domain/entities/route_entity.dart';
import '../../../timetables/domain/entities/service_entity.dart';
import '../providers/owner_providers.dart';

class ServiceEditor extends HookConsumerWidget {
  final BusinessEntity business;
  final RouteEntity route;
  final ServiceEntity? service;
  const ServiceEditor({
    super.key,
    required this.business,
    required this.route,
    this.service,
  });

  Future<void> _pick(
    BuildContext context,
    int minutes,
    void Function(int) update,
  ) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: minutes < 0 ? 8 : (minutes ~/ 60) % 24,
        minute: minutes < 0 ? 0 : minutes % 60,
      ),
    );
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EditorHeading(
          title: service == null ? 'Publish timetable' : 'Edit timetable',
          icon: Icons.schedule_outlined,
          subtitle: route.name,
        ),
        TextField(
          key: const ValueKey('bus-name'),
          controller: name,
          decoration: const InputDecoration(
            labelText: 'Bus name / registration number',
            prefixIcon: Icon(Icons.directions_bus_outlined),
          ),
        ),
        const SizedBox(height: 12),
        _TimeField(
          label: 'Departure',
          note: 'Changing departure resets stops to 15-minute intervals.',
          value: draft.departure < 0
              ? 'Choose time'
              : timeLabel(draft.departure),
          onTap: () =>
              _pick(context, draft.departure, draftController.departure),
        ),
        const SizedBox(height: 20),
        const Text(
          'Stop timings',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        for (final stop in route.stops)
          _TimeField(
            label: stop,
            value: (draft.timings[stop] ?? -1) < 0
                ? 'Choose time'
                : timeLabel(draft.timings[stop]!),
            onTap: () => _pick(
              context,
              draft.timings[stop] ?? draft.departure,
              (minutes) => draftController.stopTime(stop, minutes),
            ),
          ),
        const SizedBox(height: 12),
        const Text(
          'Days without service',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        Wrap(
          spacing: 8,
          children: [
            for (final day in weekDays)
              FilterChip(
                label: Text(day),
                selected: draft.offDays.contains(day),
                onSelected: (_) => draftController.toggleDay(day),
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: note,
          minLines: 1,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Off-timing / bypass notes (optional)',
          ),
        ),
        if (action.hasError)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              action.error.toString(),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: action.isLoading
              ? null
              : () async {
                  final saved = await ref
                      .read(ownerActionsProvider.notifier)
                      .saveService(
                        business: business,
                        route: route,
                        busName: name.text,
                        draft: draft,
                        note: note.text,
                        id: service?.id,
                      );
                  if (saved && context.mounted) Navigator.pop(context);
                },
          child: ActionShimmer(
            loading: action.isLoading,
            label: service == null ? 'Publish timetable' : 'Save timetable',
            child: Text(service == null ? 'Publish timetable' : 'Save timetable'),
          ),
        ),
      ],
    );
  }
}

/// Wrapping content keeps long stop names and enlarged text usable on phones.
class _TimeField extends StatelessWidget {
  final String label, value;
  final String? note;
  final VoidCallback onTap;
  const _TimeField({
    required this.label,
    required this.value,
    required this.onTap,
    this.note,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: AppColors.surfaceLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.schedule_outlined,
                        size: 18,
                        color: AppColors.accentInk,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          value,
                          style: const TextStyle(
                            color: AppColors.accentInk,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (note != null) ...[
                const SizedBox(height: 6),
                Text(note!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
