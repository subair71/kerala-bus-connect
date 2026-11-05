import 'package:flutter/material.dart';
import '../../../../core/utils/sample_ids.dart';
import '../../domain/entities/service_entity.dart';
import 'train_route_view.dart';

Future<void> showStopTimings(
  BuildContext context,
  ServiceEntity service, {
  required String from,
  required String to,
  required String day,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (sheetContext) => FractionallySizedBox(
    heightFactor: .9,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  isSampleId(service.id)
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
            queryFrom: from,
            queryTo: to,
            effectiveDay: day,
          ),
        ),
      ],
    ),
  ),
);
