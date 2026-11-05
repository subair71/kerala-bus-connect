import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/data/data_set.dart';
import '../../../../core/providers/firebase_providers.dart';
import '../../../../core/providers/sample_fallback.dart';
import '../../domain/entities/tracking_preview.dart';
import '../../data/repositories/firebase_tracking_repository.dart';
import '../../data/repositories/demo_tracking_repository.dart';
import '../../domain/repositories/tracking_repository.dart';

final trackingRepositoryProvider = Provider<TrackingRepository>(
  (ref) => FirebaseTrackingRepository(ref.watch(firestoreProvider)),
);
final liveTrackingProvider = StreamProvider.autoDispose<List<TrackingPreview>>(
  (ref) => ref.watch(trackingRepositoryProvider).watch(),
);
final trackingDataProvider =
    Provider.autoDispose<AsyncValue<DataSet<TrackingPreview>>>(
      (ref) => sampleFallback(
        ref.watch(liveTrackingProvider),
        const DemoTrackingRepository().previews(),
      ),
    );
final trackingSelectionProvider = NotifierProvider<TrackingSelection, int>(
  TrackingSelection.new,
);

class TrackingSelection extends Notifier<int> {
  @override
  int build() => 0;
  void select(int value) => state = value;
}

final trackingPreviewProvider = Provider.autoDispose((ref) {
  final list =
      ref.watch(trackingDataProvider).asData?.value.records ??
      <TrackingPreview>[];
  if (list.isEmpty) return null;
  final selected = ref.watch(trackingSelectionProvider);
  return list[selected.clamp(0, list.length - 1)];
});
