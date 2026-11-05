import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/providers/clock_provider.dart';
import '../../../../core/utils/sample_ids.dart';
import '../../../../core/utils/time_utils.dart';
import '../../../../core/widgets/data_notice.dart';
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
    String matchingStop(String query, bool end) => query.trim().isEmpty
        ? (end ? service.stops.lastOrNull : service.stops.firstOrNull) ?? ''
        : service.stops
                  .where(
                    (s) => s.toLowerCase().contains(query.trim().toLowerCase()),
                  )
                  .firstOrNull ??
              '';
    final boarding = matchingStop(from, false),
        destination = matchingStop(to, true);
    final departure = service.scheduledTime(boarding),
        arrival = service.scheduledTime(destination);
    final duration =
        departure != null && arrival != null && arrival >= departure
        ? arrival - departure
        : null;
    final effectiveDay = day == 'All Days' ? todayName() : day;
    final running = !service.offDays.contains(effectiveDay);
    final remaining = departure == null
        ? null
        : departure - now.hour * 60 - now.minute;
    final demo = isSampleId(service.id);
    final status = !service.operatingDaysKnown
        ? 'Operating days unavailable'
        : !running
        ? 'Not operating on $effectiveDay'
        : effectiveDay == todayName() &&
              remaining != null &&
              remaining >= 0 &&
              remaining < 120
        ? 'Scheduled in $remaining min'
        : 'Scheduled service';
    Widget endpoint(String stop, int? minutes, bool right) => Expanded(
      child: Column(
        crossAxisAlignment: right
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(
            minutes == null ? 'Time unavailable' : timeLabel(minutes),
            style: TextStyle(
              fontSize: minutes == null ? 12 : 21,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            stop.isEmpty ? 'Stop unavailable' : stop,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: right ? TextAlign.right : TextAlign.left,
            style: const TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.secondaryContainer,
                    borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.directions_bus_outlined,
                    size: 23, color: AppColors.primary)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service.busName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${service.businessName} · ${service.routeName}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (demo) ...[const SizedBox(width: 8), const DemoBadge()],
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  endpoint(boarding, departure, false),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      children: [
                        Text(
                          duration == null ? '—' : '$duration min',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const SizedBox(
                          width: 58,
                          child: Row(
                            children: [
                              Icon(
                                Icons.circle,
                                size: 5,
                                color: AppColors.primary,
                              ),
                              Expanded(
                                child: Divider(color: AppColors.outlineVariant),
                              ),
                              Icon(
                                Icons.circle,
                                size: 5,
                                color: AppColors.primary,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${service.stops.length} stops',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  endpoint(destination, arrival, true),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: running
                        ? AppColors.secondaryContainer
                        : AppColors.errorContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 12,
                      color: running ? AppColors.primary : AppColors.error,
                    ),
                  ),
                ),
                TextButton.icon(
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: const Text('View stop timings'),
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    showDragHandle: true,
                    builder: (sheetContext) => FractionallySizedBox(
                      heightFactor: .9,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    demo
                                        ? 'Sample data • not for travel planning'
                                        : 'Scheduled timings • not live GPS tracking',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Close stop timings',
                                  onPressed: () => Navigator.pop(sheetContext),
                                  icon: const Icon(Icons.close),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: TrainRouteView(
                              service: service,
                              queryFrom: boarding,
                              queryTo: destination,
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
              Text(
                service.offTimingsNote!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
