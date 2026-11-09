import 'dart:async';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../../../passenger/presentation/providers/search_providers.dart';
import '../../../platform/presentation/providers/platform_providers.dart';
import '../providers/nearby_providers.dart';

class NearbyStopsPanel extends HookConsumerWidget {
  const NearbyStopsPanel({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(platformEnabledProvider);
    useEffect(() {
      if (!enabled) return null;
      final timer = Timer.periodic(const Duration(minutes: 5), (_) {
        if (context.mounted &&
            (ModalRoute.of(context)?.isCurrent ?? true) &&
            WidgetsBinding.instance.lifecycleState ==
                AppLifecycleState.resumed) {
          ref.read(nearbyStopsProvider.notifier).refresh();
        }
      });
      return timer.cancel;
    }, [enabled]);
    if (!enabled) return const SizedBox.shrink();
    final nearby = ref.watch(nearbyStopsProvider);
    ref.listen(nearbyStopsProvider, (previous, next) {
      final data = next.asData?.value;
      if (data != null && !data.stale && data.stops.isNotEmpty) {
        ref
            .read(searchQueryProvider.notifier)
            .autoOrigin(data.stops.first.name);
        if (ref.read(searchQueryProvider).from == data.stops.first.name) {
          ref
              .read(selectedNearbyStopProvider.notifier)
              .select(data.stops.first);
        }
      }
    });
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Nearby bus stops',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh nearby stops',
                  onPressed: () =>
                      ref.read(nearbyStopsProvider.notifier).refresh(),
                  icon: const Icon(Icons.my_location),
                ),
              ],
            ),
            nearby.when(
              loading: () => const AppShimmer(
                label: 'Finding nearby stops',
                child: SkeletonText(fraction: .7, height: 14),
              ),
              error: (_, _) =>
                  const Text('Location unavailable. Search by stop name.'),
              data: (data) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (data.message != null) Text(data.message!),
                  if (data.stops.isEmpty)
                    const Text(
                      'No verified nearby stops available. Search manually.',
                    ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final stop in data.stops)
                        ActionChip(
                          label: Text(
                            data.stale
                                ? stop.name
                                : '${stop.name} · ${stop.distanceKm.toStringAsFixed(1)} km',
                          ),
                          onPressed: () {
                            ref
                                .read(searchQueryProvider.notifier)
                                .from(stop.name);
                            ref
                                .read(selectedNearbyStopProvider.notifier)
                                .select(stop);
                          },
                        ),
                    ],
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
