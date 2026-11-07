import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/providers/clock_provider.dart';
import '../../../../core/utils/sample_ids.dart';
import '../../../../core/utils/time_utils.dart';
import '../../../../core/widgets/data_notice.dart';
import '../../../../core/widgets/app_components.dart';
import '../../domain/entities/service_entity.dart';
import 'compact_service_card.dart';
import 'stop_timings_sheet.dart';

class ServiceCard extends ConsumerWidget {
  final ServiceEntity service;
  final String from, to, day;
  final bool compact;
  final int? demoFare;
  final String? demoFareLabel;
  const ServiceCard({
    super.key,
    required this.service,
    this.from = '',
    this.to = '',
    this.day = 'All Days',
    this.compact = false,
    this.demoFare,
    this.demoFareLabel,
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
    final departure = service.expectedTime(boarding),
        arrival = service.expectedTime(destination);
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
    final status = service.hasDailyAdjustment
        ? 'Updated expected times · ${service.serviceDate}'
        : !service.operatingDaysKnown
        ? 'Operating days unavailable'
        : !running
        ? 'Not operating on $effectiveDay'
        : effectiveDay == todayName() &&
              remaining != null &&
              remaining >= 0 &&
              remaining < 120
        ? 'Scheduled in $remaining min'
        : 'Scheduled service';
    void openTimings() => showStopTimings(
      context,
      service,
      from: boarding,
      to: destination,
      day: effectiveDay,
    );
    if (compact)
      return CompactServiceCard(
        service: service,
        boarding: boarding,
        destination: destination,
        status: status,
        departure: departure,
        arrival: arrival,
        duration: duration,
        demo: demo,
        running: running,
        demoFare: demoFare,
        demoFareLabel: demoFareLabel,
        onViewStops: openTimings,
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
                const AppIconTile(
                  Icons.directions_bus_outlined,
                  emphasized: true,
                ),
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
            _JourneyTimes(
              boarding: boarding,
              destination: destination,
              departure: departure,
              arrival: arrival,
              duration: duration,
              stopCount: service.stops.length,
            ),
            const SizedBox(height: 8),
            if (service.hasDailyAdjustment)
              Text(
                'Scheduled: ${timeLabel(service.scheduledTime(boarding)!)} → '
                '${timeLabel(service.scheduledTime(destination)!)} · '
                'Delay: +${arrival! - service.scheduledTime(destination)!} min at destination',
              ),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                AppStatusBadge(
                  label: status,
                  icon: Icons.schedule_rounded,
                  foreground: !service.operatingDaysKnown
                      ? AppColors.onSurfaceVariant
                      : running
                      ? AppColors.accentInk
                      : AppColors.error,
                  background: !service.operatingDaysKnown
                      ? AppColors.surfaceLow
                      : running
                      ? AppColors.secondaryContainer
                      : AppColors.errorContainer,
                ),
                FilledButton.tonalIcon(
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: const Text('View stop timings'),
                  onPressed: openTimings,
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

/// Adapts the existing schedule display without changing operational values.
class _JourneyTimes extends StatelessWidget {
  final String boarding, destination;
  final int? departure, arrival, duration;
  final int stopCount;
  const _JourneyTimes({
    required this.boarding,
    required this.destination,
    required this.departure,
    required this.arrival,
    required this.duration,
    required this.stopCount,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.journeySurface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final compact = constraints.maxWidth < 320 || scale > 1.2;
        final stacked = scale > 1.6;
        Widget endpoint(bool end) {
          final minutes = end ? arrival : departure;
          final stop = end ? destination : boarding;
          final alignRight = end && !stacked;
          return Column(
            crossAxisAlignment: alignRight
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Text(
                end ? 'Arrival' : 'Departure',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                minutes == null ? 'Time unavailable' : timeLabel(minutes),
                style: TextStyle(
                  fontSize: minutes == null ? 13 : 22,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.5,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                stop.isEmpty ? 'Stop unavailable' : stop,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: alignRight ? TextAlign.right : TextAlign.left,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (stacked) ...[
              endpoint(false),
              const SizedBox(height: 16),
              endpoint(true),
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: endpoint(false)),
                  if (!compact)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Column(
                        children: [
                          Text(
                            duration == null ? '—' : '$duration min',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accentInk,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const SizedBox(
                            width: 72,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.trip_origin,
                                  size: 10,
                                  color: AppColors.accentInk,
                                ),
                                Expanded(
                                  child: Divider(
                                    color: AppColors.outlineVariant,
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 16,
                                  color: AppColors.accentInk,
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '$stopCount stops',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    const SizedBox(width: 16),
                  Expanded(child: endpoint(true)),
                ],
              ),
            if (compact) ...[
              const Divider(height: 24),
              Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  Text(
                    duration == null ? 'Duration unavailable' : '$duration min',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accentInk,
                    ),
                  ),
                  Text(
                    '$stopCount stops',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    ),
  );
}
