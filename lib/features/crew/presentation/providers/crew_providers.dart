import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../data/repositories/demo_crew_repository.dart';
import '../../domain/repositories/crew_repository.dart';
import '../../domain/entities/crew_assignment.dart';

final crewRepositoryProvider = Provider<CrewRepository>((ref) => const DemoCrewRepository());
typedef CrewFilter = ({String query, String shift});
final crewFilterProvider = NotifierProvider<CrewFilterController, CrewFilter>(CrewFilterController.new);
class CrewFilterController extends Notifier<CrewFilter> {
  @override
  CrewFilter build() => (query: '', shift: 'All');
  void search(String value) => state = (query: value.trim().toLowerCase(), shift: state.shift);
  void shift(String value) => state = (query: state.query, shift: value);
}
final filteredCrewProvider = Provider.autoDispose<List<CrewAssignment>>((ref) {
  final filter = ref.watch(crewFilterProvider);
  return ref.watch(crewRepositoryProvider).assignments().where((item) =>
    (filter.shift == 'All' || item.shift == filter.shift) &&
    '${item.name} ${item.role} ${item.vehicle}'.toLowerCase().contains(filter.query)).toList();
});
