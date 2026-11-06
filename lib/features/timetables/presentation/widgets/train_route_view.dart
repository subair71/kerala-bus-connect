import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/utils/sample_ids.dart';
import '../../../../core/utils/time_utils.dart';
import '../../../../core/widgets/data_notice.dart';
import '../../domain/entities/service_entity.dart';

class TrainRouteView extends StatelessWidget {
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
  Widget build(BuildContext context) => ListView.builder(
    padding: const EdgeInsets.all(20),
    itemCount: service.stops.length + 1,
    itemBuilder: (context, index) {
      if (index == 0)
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Stop sequence',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(service.busName),
            Text(
              service.routeName,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (isSampleId(service.id)) const DataNotice(demo: true),
            Text(
              !service.operatingDaysKnown
                  ? 'Operating days unavailable'
                  : service.offDays.contains(effectiveDay)
                  ? 'Not operating on $effectiveDay'
                  : service.hasDailyAdjustment
                  ? 'Updated expected times • ${service.serviceDate}'
                  : 'Scheduled timetable • $effectiveDay',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
          ],
        );
      final stop = service.stops[index - 1];
      final minutes = service.expectedTime(stop);
      final scheduled = service.scheduledTime(stop);
      final selected =
          stop.toLowerCase() == queryFrom.toLowerCase() ||
          stop.toLowerCase() == queryTo.toLowerCase();
      return Stack(
        children: [
          if (index != service.stops.length)
            const Positioned(
              left: 13,
              top: 16,
              bottom: 0,
              child: SizedBox(
                width: 2,
                child: ColoredBox(color: AppColors.border),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 28,
                child: Center(
                  child: Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.only(top: 5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? AppColors.primary : Colors.white,
                      border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : AppColors.outlineVariant,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        minutes == null
                            ? 'Time unavailable'
                            : timeLabel(minutes),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (minutes != null && minutes >= 1440)
                        Text(
                          minutes < 2880
                              ? 'Next day'
                              : 'Day +${minutes ~/ 1440}',
                        ),
                      if (minutes != null &&
                          scheduled != null &&
                          minutes != scheduled)
                        Text(
                          'Scheduled ${timeLabel(scheduled)} · +${minutes - scheduled} min',
                        ),
                      const SizedBox(height: 4),
                      Text(
                        stop,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      if (selected)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            'Selected stop',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accentInk,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}
