import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../timetables/presentation/providers/timetable_providers.dart';
import '../../domain/entities/trip_plan.dart';
import '../../domain/entities/timetable_suggestion.dart';
import 'trip_editor.dart';

class TimetableSuggestions extends HookConsumerWidget {
  final TripPlan plan;
  const TimetableSuggestions({super.key, required this.plan});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final known = ref.watch(ownerServicesProvider).asData?.value ?? [];
    final form = useMemoized(() => GlobalKey<FormState>());
    final factor = useTextEditingController(text: '1');
    final dwell = useTextEditingController(text: '0');
    final durations = useMemoized(() => [
      for (var i = 1; i < plan.stops.length; i++)
        TextEditingController(text: (() {
          for (final service in known) {
            final names = service.stops.map((s) => s.trim().toLowerCase()).toList();
            final start = names.indexOf(plan.stops[i - 1].name.trim().toLowerCase());
            final end = names.indexOf(plan.stops[i].name.trim().toLowerCase());
            if (start >= 0 && end == start + 1) {
              final a = service.scheduledTime(service.stops[start]);
              final b = service.scheduledTime(service.stops[end]);
              if (a != null && b != null && b > a) return '${b - a}';
            }
          }
          return '';
        })()),
    ]);
    useEffect(() => () { for (final c in durations) { c.dispose(); } }, [durations]);
    final error = useState<String?>(null);
    final preview = useState<TripPlan?>(null);
    return AlertDialog(
      title: const Text('Suggest stop timings'),
      content: SizedBox(width: 480, child: SingleChildScrollView(child: Form(
        key: form,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Known intervals are reused from your approved timetables. Enter missing road durations. Existing entered times are preserved. Review before applying; nothing is published here.'),
          for (var i = 0; i < durations.length; i++) TextFormField(
            controller: durations[i],
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: '${plan.stops[i].name} → ${plan.stops[i + 1].name} (minutes)'),
            validator: (v) => (int.tryParse(v ?? '') ?? 0) < 1 ? 'Enter travel minutes' : null,
          ),
          TextFormField(controller: factor, decoration: const InputDecoration(labelText: 'Travel adjustment factor (0.5–3)')),
          TextFormField(controller: dwell, decoration: const InputDecoration(labelText: 'Additional time at intermediate stops (minutes)')),
          if (error.value != null) Text(error.value!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          if (preview.value != null) ...[
            const Divider(),
            for (final stop in preview.value!.stops) Text('${stop.name}: ${tripTimeLabel(stop.minutes)}'),
          ],
        ]),
      ))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        OutlinedButton(onPressed: () {
          if (!form.currentState!.validate()) return;
          try {
            preview.value = suggestTimetable(plan, durations.map((c) => int.parse(c.text)).toList(),
              factor: double.tryParse(factor.text) ?? double.nan,
              stopMinutes: int.tryParse(dwell.text) ?? -1);
            error.value = null;
          } catch (e) { error.value = e.toString(); preview.value = null; }
        }, child: const Text('Preview')),
        FilledButton(onPressed: preview.value == null ? null : () => Navigator.pop(context, preview.value),
          child: const Text('Apply to draft')),
      ],
    );
  }
}
