import '../../../trips/domain/entities/trip_plan.dart';
import '../../../trips/presentation/providers/trip_providers.dart';
import 'dart:async';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/providers/clock_provider.dart';
import '../../../../core/constants/transit_constants.dart';
import '../../../../core/utils/time_utils.dart';
import '../../../timetables/domain/entities/service_entity.dart';
import '../../../timetables/presentation/providers/timetable_providers.dart';
import '../../domain/entities/search_query.dart';
import '../../domain/services/service_search_index.dart';

final searchQueryProvider = NotifierProvider<SearchController, SearchQuery>(
  SearchController.new,
);

// Service dates select recurring operating days and isolated daily adjustments.
final journeyTodayProvider = Provider.autoDispose<DateTime>((ref) {
  final now = ref.watch(clockProvider.select((value) => value.asData?.value));
  final date = now ?? keralaNow();
  return DateTime(date.year, date.month, date.day);
});
final journeyDatesProvider = Provider.autoDispose<List<DateTime>>((ref) {
  final today = ref.watch(journeyTodayProvider);
  return List.unmodifiable(
    List.generate(7, (i) => DateTime(today.year, today.month, today.day + i)),
  );
});

class SearchController extends Notifier<SearchQuery> {
  @override
  SearchQuery build() {
    ref.listen(journeyTodayProvider, (previous, next) {
      if (previous != null && state.serviceDate == previous) {
        state = state.copyWith(serviceDate: next,
          filterDay: weekDays[next.weekday - 1]);
      }
    });
    return SearchQuery(serviceDate: ref.read(journeyTodayProvider),
      filterDay: weekDays[ref.read(journeyTodayProvider).weekday - 1]);
  }
  void journeyDate(DateTime date) {
    final today = ref.read(journeyTodayProvider);
    final isToday =
        date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
    state = state.copyWith(
      serviceDate: DateTime(date.year, date.month, date.day),
      filterDay: weekDays[date.weekday - 1],
      onlyRunningToday: isToday && state.onlyRunningToday,
    );
  }

  void from(String value) => state = state.copyWith(from: value);
  void to(String value) => state = state.copyWith(to: value);
  void swap() => state = state.copyWith(from: state.to, to: state.from);
  void day(String value) {
    final date = ref.read(journeyDatesProvider)
        .where((d) => weekDays[d.weekday - 1] == value).firstOrNull;
    state = state.copyWith(filterDay: value, serviceDate: date,
      clearDate: date == null);
  }
  void runningToday(bool value) =>
      state = state.copyWith(onlyRunningToday: value);
}

final searchDebounceDurationProvider = Provider<Duration>(
  (ref) => const Duration(milliseconds: 200),
);
final debouncedSearchProvider =
    NotifierProvider.autoDispose<DebouncedSearch, SearchQuery>(
      DebouncedSearch.new,
    );

class DebouncedSearch extends Notifier<SearchQuery> {
  /// Explicit search submissions must use the latest fields immediately.
  void flush() => state = ref.read(searchQueryProvider);

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

final serviceIndexProvider =
    Provider.autoDispose<AsyncValue<ServiceSearchIndex>>(
      (ref) => ref
          .watch(serviceCatalogProvider)
          .whenData((data) => ServiceSearchIndex(data.records)),
    );

final passengerDailyUpdatesUnavailableProvider = Provider.autoDispose<bool>((ref) {
  final query = ref.watch(debouncedSearchProvider);
  final records = ref.watch(serviceCatalogProvider).asData?.value.records;
  if (query.serviceDate == null ||
      !(records?.any((s) => s.busId.isNotEmpty) ?? false)) return false;
  return ref.watch(dailyAdjustmentsProvider(serviceDateKey(query.serviceDate!))).hasError;
});

final departureResultsProvider =
    Provider.autoDispose<AsyncValue<List<ServiceEntity>>>((ref) {
      final query = ref.watch(debouncedSearchProvider);
      final today = ref.watch(todayProvider);
      return ref.watch(serviceIndexProvider).whenData((index) {
        var services = index.search(
          from: query.from, to: query.to, filterDay: query.filterDay,
          onlyRunningToday: query.onlyRunningToday, today: today,
        );
        if (query.serviceDate != null && services.any((s) => s.busId.isNotEmpty)) {
          final date = serviceDateKey(query.serviceDate!);
          final daily = ref.watch(dailyAdjustmentsProvider(date));
          if (daily.hasValue && !daily.hasError && !daily.isLoading) {
            final adjustments = {
              for (final item in daily.requireValue) item.tripId: item,
            };
            services = [
              for (final service in services)
                adjustments[service.id]?.apply(service) ?? service,
            ];
          }
        }
        int boardingTime(ServiceEntity service) {
          final stop = query.from.trim().isEmpty ? service.stops.firstOrNull :
              service.stops.where((s) =>
                s.toLowerCase().contains(query.from.trim().toLowerCase())).firstOrNull;
          return stop == null ? 999999 : service.expectedTime(stop) ?? 999999;
        }
        return List.unmodifiable([...services]
          ..sort((a, b) => boardingTime(a).compareTo(boardingTime(b))));
      });
    });
