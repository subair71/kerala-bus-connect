import 'dart:async';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/providers/clock_provider.dart';
import '../../../../core/utils/time_utils.dart';
import '../../../timetables/domain/entities/service_entity.dart';
import '../../../timetables/presentation/providers/timetable_providers.dart';
import '../../domain/entities/search_query.dart';
import '../../domain/services/service_search_index.dart';

final searchQueryProvider = NotifierProvider<SearchController, SearchQuery>(SearchController.new);
class SearchController extends Notifier<SearchQuery> {
  @override
  SearchQuery build() => SearchQuery(filterDay: todayName());
  void from(String value) => state = state.copyWith(from: value);
  void to(String value) => state = state.copyWith(to: value);
  void swap() => state = state.copyWith(from: state.to, to: state.from);
  void day(String value) => state = state.copyWith(filterDay: value);
  void runningToday(bool value) => state = state.copyWith(onlyRunningToday: value);
}

final searchDebounceDurationProvider = Provider<Duration>((ref) => const Duration(milliseconds: 200));
final debouncedSearchProvider = NotifierProvider.autoDispose<DebouncedSearch, SearchQuery>(DebouncedSearch.new);
class DebouncedSearch extends Notifier<SearchQuery> {
  @override
  SearchQuery build() {
    Timer? timer;
    final delay = ref.watch(searchDebounceDurationProvider);
    ref.listen(searchQueryProvider, (previous, next) {
      timer?.cancel();
      timer = Timer(delay, () {
        if (ref.mounted) state = next;
      });
    });
    ref.onDispose(() => timer?.cancel());
    return ref.read(searchQueryProvider);
  }
}

final serviceIndexProvider = Provider.autoDispose<AsyncValue<ServiceSearchIndex>>((ref) =>
    ref.watch(publishedServicesProvider).whenData(ServiceSearchIndex.new));

final departureResultsProvider = Provider.autoDispose<AsyncValue<List<ServiceEntity>>>((ref) {
  final query = ref.watch(debouncedSearchProvider);
  final today = ref.watch(todayProvider);
  return ref.watch(serviceIndexProvider).whenData((index) => index.search(
    from: query.from, to: query.to, filterDay: query.filterDay,
    onlyRunningToday: query.onlyRunningToday, today: today,
  ));
});
