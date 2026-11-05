import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/widgets/page_heading.dart';
import '../providers/tracking_providers.dart';

class TrackingPage extends ConsumerWidget {
  const TrackingPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(trackingPreviewProvider);
    final vehicles = ref.watch(trackingRepositoryProvider).previews();
    final selected = ref.watch(trackingSelectionProvider);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const PageHeading(
              title: 'Bus tracking preview',
              subtitle: 'Demo only • no live GPS data is connected.',
            ),
            DropdownButton<int>(
              value: selected,
              isExpanded: true,
              items: [
                for (var i = 0; i < vehicles.length; i++)
                  DropdownMenuItem(value: i, child: Text(vehicles[i].vehicle)),
              ],
              onChanged: (value) {
                if (value != null)
                  ref.read(trackingSelectionProvider.notifier).select(value);
              },
            ),
            const SizedBox(height: 20),
            Card(
              child: Column(
                children: [
                  for (var i = 0; i < preview.stops.length; i++)
                    ListTile(
                      leading: Icon(
                        i == preview.currentStop
                            ? Icons.directions_bus
                            : Icons.location_on_outlined,
                        color: i <= preview.currentStop
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey,
                      ),
                      title: Text(preview.stops[i]),
                      subtitle: i == preview.currentStop
                          ? const Text('Example position')
                          : null,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
