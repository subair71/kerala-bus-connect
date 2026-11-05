import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/providers/clock_provider.dart';
import '../../../../core/utils/time_utils.dart';
import '../../domain/entities/service_entity.dart';

class TrainRouteView extends ConsumerWidget {
  final ServiceEntity service;
  final String queryFrom, queryTo, effectiveDay;
  const TrainRouteView({
    super.key,
    required this.service,
    required this.queryFrom,
    required this.queryTo,
    required this.effectiveDay,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider).asData?.value ?? keralaNow();
    final minute = now.hour * 60 + now.minute;
    final off = service.offDays.contains(effectiveDay);
    final today = effectiveDay == todayName();
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: service.stops.length + 1,
      itemBuilder: (context, index) {
        if (index == 0)
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                service.busName,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(service.routeName),
              const SizedBox(height: 8),
              Text(
                off
                    ? 'Not operating on $effectiveDay'
                    : 'Published timetable • $effectiveDay',
              ),
              if (service.offTimingsNote?.isNotEmpty ?? false)
                Text(service.offTimingsNote!),
              const SizedBox(height: 20),
            ],
          );
        final stop = service.stops[index - 1];
        final time =
            service.stopTimings[stop] ??
            service.departureMinutes + (index - 1) * 15;
        final selected =
            stop.toLowerCase() == queryFrom.trim().toLowerCase() ||
            stop.toLowerCase() == queryTo.trim().toLowerCase();
        final passed = today && !off && time <= minute;
        return Card(
          color: selected
              ? Theme.of(context).colorScheme.primaryContainer
              : null,
          child: ListTile(
            leading: CircleAvatar(
              child: passed ? const Icon(Icons.check) : Text('$index'),
            ),
            title: Text(stop),
            subtitle: Text(selected ? 'Selected stop' : 'Scheduled stop'),
            trailing: Text(
              timeLabel(time),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        );
      },
    );
  }
}
