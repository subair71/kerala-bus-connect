import 'dart:async';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/data/data_set.dart';
import '../../../../core/providers/cache_lifetime.dart';
import '../../../../core/providers/firebase_providers.dart';
import '../../../../core/providers/sample_fallback.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/repositories/firebase_crew_repository.dart';
import '../../data/repositories/demo_crew_repository.dart';
import '../../domain/repositories/crew_repository.dart';
import '../../domain/entities/crew_assignment.dart';

final crewRepositoryProvider = Provider<CrewRepository>(
  (ref) => FirebaseCrewRepository(ref.watch(firestoreProvider)),
);
final liveCrewProvider = StreamProvider.autoDispose<List<CrewAssignment>>(
  (ref) {
    retainWhileIdle(ref, ref.watch(liveDataCacheDurationProvider));
    final owner = ref.watch(ownerIdProvider);
    if (owner == null) return Stream.value([]);
    return ref.watch(crewRepositoryProvider).watch(owner);
  },
  // Firestore owns reconnection; expose errors to the labelled preview fallback.
  retry: (_, _) => null,
);
final crewDataProvider =
    Provider.autoDispose<AsyncValue<DataSet<CrewAssignment>>>(
      (ref) => sampleFallback(
        ref.watch(liveCrewProvider),
        const DemoCrewRepository().assignments(),
        previewWhileLoading: true,
      ),
    );
typedef CrewFilter = ({String query, String shift});
final crewFilterProvider = NotifierProvider<CrewFilterController, CrewFilter>(
  CrewFilterController.new,
);

class CrewFilterController extends Notifier<CrewFilter> {
  @override
  CrewFilter build() => (query: '', shift: 'All');
  void search(String value) =>
      state = (query: value.trim().toLowerCase(), shift: state.shift);
  void shift(String value) => state = (query: state.query, shift: value);
}

final filteredCrewProvider = Provider.autoDispose<List<CrewAssignment>>((ref) {
  final query = ref.watch(debouncedCrewQueryProvider);
  final shift = ref.watch(crewFilterProvider.select((filter) => filter.shift));
  return ref
          .watch(crewDataProvider)
          .asData
          ?.value
          .records
          .where(
            (item) =>
                (shift == 'All' || item.shift == shift) &&
                '${item.name} ${item.role} ${item.vehicle}'
                    .toLowerCase()
                    .contains(query),
          )
          .toList() ??
      [];
});

final debouncedCrewQueryProvider =
    NotifierProvider.autoDispose<DebouncedCrewQuery, String>(
      DebouncedCrewQuery.new,
    );

class DebouncedCrewQuery extends Notifier<String> {
  @override
  String build() {
    Timer? timer;
    ref.listen(crewFilterProvider.select((filter) => filter.query), (_, next) {
      timer?.cancel();
      timer = Timer(const Duration(milliseconds: 200), () {
        if (ref.mounted) state = next;
      });
    });
    ref.onDispose(() => timer?.cancel());
    return ref.read(crewFilterProvider).query;
  }
}
