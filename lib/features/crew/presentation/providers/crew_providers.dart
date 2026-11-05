import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/data/data_set.dart';
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
final liveCrewProvider = StreamProvider.autoDispose<List<CrewAssignment>>((
  ref,
) {
  final owner = ref.watch(ownerIdProvider);
  if (owner == null) return Stream.value([]);
  return ref.watch(crewRepositoryProvider).watch(owner);
});
final crewDataProvider =
    Provider.autoDispose<AsyncValue<DataSet<CrewAssignment>>>(
      (ref) => sampleFallback(
        ref.watch(liveCrewProvider),
        const DemoCrewRepository().assignments(),
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
  final filter = ref.watch(crewFilterProvider);
  return ref
          .watch(crewDataProvider)
          .asData
          ?.value
          .records
          .where(
            (item) =>
                (filter.shift == 'All' || item.shift == filter.shift) &&
                '${item.name} ${item.role} ${item.vehicle}'
                    .toLowerCase()
                    .contains(filter.query),
          )
          .toList() ??
      [];
});
