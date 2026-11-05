import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/widgets/data_notice.dart';
import '../../../timetables/presentation/providers/timetable_providers.dart';
import '../../../timetables/presentation/widgets/service_card.dart';

/// Read-only examples are separate from the signed-in owner's records.
class SampleOwnerPreview extends ConsumerWidget {
  const SampleOwnerPreview({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businesses = ref.watch(sampleBusinessesProvider);
    final routes = ref.watch(sampleRoutesProvider);
    final services = ref.watch(sampleServicesProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 24),
      const DataNotice(demo: true),
      Text('Business preview', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 4),
      const Text('Read-only examples. Create your own business to manage routes and publish services.',
        style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
      const SizedBox(height: 16),
      for (final business in businesses) Card(child: Padding(padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Icon(Icons.business_outlined, color: AppColors.primary),
            const SizedBox(width: 8), Expanded(child: Text(business.name, style: Theme.of(context).textTheme.titleMedium)),
            const DemoBadge()]),
          const SizedBox(height: 12),
          for (final route in routes.where((r) => r.businessId == business.id)) ...[
            Text(route.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(route.stops.join(' → '), style: Theme.of(context).textTheme.bodySmall),
          ],
        ]))),
      ServiceCard(service: services.first),
    ]);
  }
}
