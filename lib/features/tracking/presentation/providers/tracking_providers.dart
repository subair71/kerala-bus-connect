import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../data/repositories/demo_tracking_repository.dart';
import '../../domain/repositories/tracking_repository.dart';

final trackingRepositoryProvider = Provider<TrackingRepository>((ref) => const DemoTrackingRepository());
final trackingSelectionProvider = NotifierProvider<TrackingSelection, int>(TrackingSelection.new);
class TrackingSelection extends Notifier<int> {
  @override
  int build() => 0;
  void select(int value) => state = value;
}
final trackingPreviewProvider = Provider.autoDispose((ref) {
  final list = ref.watch(trackingRepositoryProvider).previews();
  final selected = ref.watch(trackingSelectionProvider);
  return list[selected.clamp(0, list.length - 1)];
});
