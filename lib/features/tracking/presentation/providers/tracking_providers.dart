import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/data/data_set.dart';
import '../../../../core/providers/cache_lifetime.dart';
import '../../../../core/providers/firebase_providers.dart';
import '../../../../core/providers/sample_fallback.dart';
import '../../domain/entities/tracking_preview.dart';
import '../../data/repositories/firebase_tracking_repository.dart';
import '../../data/repositories/demo_tracking_repository.dart';
import '../../domain/repositories/tracking_repository.dart';

final trackingRepositoryProvider = Provider<TrackingRepository>(
  (ref) => FirebaseTrackingRepository(ref.watch(firestoreProvider)),
);
final trackingCursorsProvider =
    NotifierProvider.autoDispose<TrackingCursors, List<String>>(
      TrackingCursors.new,
    );

class TrackingCursors extends Notifier<List<String>> {
  @override
  List<String> build() => const [];
  void next(String lastId) => state = [...state, lastId];
  void previous() {
    if (state.isNotEmpty) state = state.sublist(0, state.length - 1);
  }
}

final liveTrackingProvider = StreamProvider.autoDispose<List<TrackingPreview>>(
  (ref) {
    retainWhileIdle(ref, ref.watch(liveDataCacheDurationProvider));
    return ref
        .watch(trackingRepositoryProvider)
        .watch(after: ref.watch(trackingCursorsProvider).lastOrNull);
  },
  // Firestore owns reconnection; expose errors to the labelled preview fallback.
  retry: (_, _) => null,
);
final trackingDataProvider =
    Provider.autoDispose<AsyncValue<DataSet<TrackingPreview>>>((ref) {
      final live = ref
          .watch(liveTrackingProvider)
          .whenData((rows) => rows.take(trackingPageSize).toList());
      if (ref.watch(trackingCursorsProvider).isNotEmpty)
        return live.whenData((rows) => DataSet(rows));
      return sampleFallback(live, const DemoTrackingRepository().previews());
    });
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
