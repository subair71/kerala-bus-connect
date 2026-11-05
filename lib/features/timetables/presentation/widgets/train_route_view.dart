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
    padding: const EdgeInsets.all(16),
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
              service.offDays.contains(effectiveDay)
                  ? 'Not operating on $effectiveDay'
                  : 'Scheduled timetable • $effectiveDay',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
          ],
        );
      final stop = service.stops[index - 1];
      final minutes = service.scheduledTime(stop);
      final selected =
          stop.toLowerCase() == queryFrom.toLowerCase() ||
          stop.toLowerCase() == queryTo.toLowerCase();
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 28,
              child: Column(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.only(top: 5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? AppColors.primary : Colors.white,
                      border: Border.all(color: AppColors.primary, width: 2),
                    ),
                  ),
                  Expanded(
                    child: VerticalDivider(
                      width: 2,
                      thickness: 2,
                      color: index == service.stops.length
                          ? Colors.transparent
                          : AppColors.border,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      minutes == null ? 'Time unavailable' : timeLabel(minutes),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(stop),
                    if (selected)
                      const Text(
                        'Selected stop',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.primary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
