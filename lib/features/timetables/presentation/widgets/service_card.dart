import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/providers/clock_provider.dart';
import '../../../../core/utils/time_utils.dart';
import '../../domain/entities/service_entity.dart';
import 'train_route_view.dart';

class ServiceCard extends ConsumerWidget {
  final ServiceEntity service;
  final String from, to, day;
  const ServiceCard({
    super.key,
    required this.service,
    this.from = '',
    this.to = '',
    this.day = 'All Days',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider).asData?.value ?? keralaNow();
    final term = from.trim().toLowerCase();
    final boarding =
        service.stops
            .where((s) => s.toLowerCase().contains(term))
            .firstOrNull ??
        '';
    final minutes = service.getBoardingTime(boarding);
    final remaining = minutes - now.hour * 60 - now.minute;
    final effectiveDay = day == 'All Days' ? todayName() : day;
    final running = !service.offDays.contains(effectiveDay);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.directions_bus, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service.busName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        service.businessName,
                        style: const TextStyle(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  timeLabel(minutes),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              service.routeName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              service.stops.join(' → '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('${service.stops.length} stops'),
                Text(
                  !running
                      ? 'Not operating on $effectiveDay'
                      : day == todayName() && remaining >= 0 && remaining < 120
                      ? 'Scheduled in $remaining min'
                      : 'Scheduled service',
                  style: TextStyle(
                    color: running ? AppColors.secondary : AppColors.error,
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.alt_route, size: 18),
                  label: const Text('View stop timings'),
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (_) => FractionallySizedBox(
                      heightFactor: .9,
                      child: Column(
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(10),
                            child: Text(
                              'Timetable estimates • not live GPS tracking',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                          Expanded(
                            child: TrainRouteView(
                              service: service,
                              queryFrom: boarding,
                              queryTo: to,
                              effectiveDay: effectiveDay,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (service.offTimingsNote?.isNotEmpty ?? false)
              Text(service.offTimingsNote!),
          ],
        ),
      ),
    );
  }
}
