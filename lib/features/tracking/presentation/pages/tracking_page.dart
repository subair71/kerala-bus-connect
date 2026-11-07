import '../../../../core/widgets/data_notice.dart';
import '../../../../core/widgets/async_status.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/widgets/page_heading.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/widgets/app_components.dart';
import '../providers/tracking_providers.dart';

class TrackingPage extends ConsumerWidget {
  const TrackingPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(trackingPreviewProvider);
    final data = ref.watch(trackingDataProvider);
    if (preview == null) return const Center(child: AsyncStatus(loading: true));
    final vehicles = data.asData!.value.records;
    final selected = ref
        .watch(trackingSelectionProvider)
        .clamp(0, vehicles.length - 1);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: ListView.builder(
          key: PageStorageKey(
            'tracking-${preview.id.isEmpty ? preview.vehicle : preview.id}',
          ),
          padding: const EdgeInsets.all(16),
          itemCount: preview.stops.length + 1,
          itemBuilder: (context, index) {
            if (index == 0)
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const PageHeading(
                    title: 'Bus tracking preview',
                    subtitle: 'Route position preview • not live GPS tracking.',
                  ),
                  DataNotice(
                    demo: data.asData!.value.isDemo,
                    unavailable: data.asData!.value.unavailable,
                    retry: () => ref.invalidate(liveTrackingProvider),
                  ),
                  DropdownButtonFormField<int>(
                    key: ValueKey(selected),
                    initialValue: selected,
                    decoration: const InputDecoration(
                      labelText: 'Vehicle',
                      prefixIcon: Icon(Icons.directions_bus_outlined),
                    ),
                    isExpanded: true,
                    items: [
                      for (var i = 0; i < vehicles.length; i++)
                        DropdownMenuItem(
                          value: i,
                          child: Text(
                            vehicles[i].vehicle,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null)
                        ref
                            .read(trackingSelectionProvider.notifier)
                            .select(value);
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              );
            final i = index - 1;
            final first = i == 0;
            final last = i == preview.stops.length - 1;
            return Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(
                  top: first ? const Radius.circular(18) : Radius.zero,
                  bottom: last ? const Radius.circular(18) : Radius.zero,
                ),
                side: const BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(8, first ? 8 : 0, 8, last ? 8 : 0),
                child: ListTile(
                  tileColor: i == preview.currentStop
                      ? AppColors.secondaryContainer
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: i == preview.currentStop
                      ? const AppIconTile(
                          Icons.directions_bus_outlined,
                          size: 36,
                          emphasized: true,
                        )
                      : Icon(
                          Icons.location_on_outlined,
                          color: i < preview.currentStop
                              ? AppColors.primary
                              : AppColors.outline,
                        ),
                  title: Text(preview.stops[i]),
                  subtitle: i == preview.currentStop
                      ? Text(
                          data.asData!.value.isDemo
                              ? 'Example position'
                              : 'Reported position',
                        )
                      : null,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
