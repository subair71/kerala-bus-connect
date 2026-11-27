import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kerala_bus_connect/features/tracking/domain/entities/tracking_preview.dart';
import 'package:kerala_bus_connect/features/tracking/domain/repositories/tracking_repository.dart';
import 'package:kerala_bus_connect/features/tracking/presentation/providers/tracking_providers.dart';

class PagedTestRepository implements TrackingRepository {
  final calls = <String?>[];
  @override
  Stream<List<TrackingPreview>> watch({String? after}) {
    calls.add(after);
    final first = after == null ? 0 : int.parse(after) + 1;
    final rows = List.generate(
      22,
      (i) => TrackingPreview('Bus $i', ['A', 'B'], 0, id: '$i'),
    );
    return Stream.value(rows.skip(first).take(trackingPageSize + 1).toList());
  }
}

void main() {
  test(
    'switching tracking pages advances after the last visible vehicle and restores page one',
    () async {
      final repo = PagedTestRepository();
      final ref = ProviderContainer(
        overrides: [trackingRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(ref.dispose);
      ref.listen(trackingDataProvider, (_, _) {});
      await ref.read(liveTrackingProvider.future);
      final first = ref.read(trackingDataProvider).requireValue.records;
      expect(first.length, trackingPageSize);
      ref.read(trackingCursorsProvider.notifier).next(first.last.id);
      await ref.read(liveTrackingProvider.future);
      final second = ref.read(trackingDataProvider).requireValue.records;
      expect(second.map((v) => v.id), ['20', '21']);
      ref.read(trackingCursorsProvider.notifier).previous();
      await ref.read(liveTrackingProvider.future);
      expect(ref.read(trackingDataProvider).requireValue.records.first.id, '0');
      expect(repo.calls, [null, '19', null]);
    },
  );
}
