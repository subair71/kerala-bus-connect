import '../../data/departure_reminder.dart';
import '../../../../core/constants/transit_constants.dart';
import '../../../trips/domain/entities/trip_plan.dart';
import '../../../trips/presentation/providers/trip_providers.dart';
import '../../../platform/presentation/providers/platform_providers.dart';
import '../../../passenger/presentation/providers/paged_search_provider.dart';
import '../../../passenger/presentation/providers/search_providers.dart';
import '../../../passenger/domain/services/departure_order.dart';
import '../../../timetables/presentation/providers/timetable_providers.dart';
import 'dart:convert';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/providers/firebase_providers.dart';
import '../../data/firebase_journey_repository.dart';
import '../../domain/journey_repository.dart';
import '../../../timetables/domain/entities/service_entity.dart';
import '../../domain/journey_filters.dart';

final journeyFiltersProvider =
    NotifierProvider<FilterController, JourneyFilters>(FilterController.new);

class FilterController extends Notifier<JourneyFilters> {
  @override
  JourneyFilters build() => const JourneyFilters();
  void apply(JourneyFilters value) => state = value;
}

final journeyBookProvider =
    AsyncNotifierProvider<JourneyBook, List<SavedJourney>>(JourneyBook.new);

class JourneyBook extends AsyncNotifier<List<SavedJourney>> {
  Future<void> _pending = Future.value();
  @override
  Future<List<SavedJourney>> build() =>
      ref.watch(journeyRepositoryProvider).readBookmarks();

  Future<void> edit(SavedJourney item, {bool remove = false}) {
    final operation = _pending.then((_) async {
      final initial = await future;
      final rows = [
        for (final entry in initial)
          if (entry.key != item.key) entry,
      ];
      if (!remove) rows.insert(0, item);
      if (item.kind == 'recent') {
        var count = 0;
        rows.removeWhere((entry) => entry.kind == 'recent' && ++count > 12);
      }
      await ref.read(journeyRepositoryProvider).writeBookmarks(rows);
      if (ref.mounted) state = AsyncData(List.unmodifiable(rows));
    });
    _pending = operation.catchError((Object _) {});
    return operation;
  }
}

final journeyRepositoryProvider = Provider<JourneyRepository>(
  (ref) => FirebaseJourneyRepository(
    () => ref.read(firestoreProvider),
    ref.watch(platformRepositoryProvider),
    () => SharedPreferencesAsync(),
  ),
);
final sampleCatalogueProvider = FutureProvider.autoDispose<SampleCatalogue>(
  (ref) => ref.watch(journeyRepositoryProvider).samples(),
);
typedef TimetableKey = ({String id, String date, bool regular});
final journeyTimetableProvider = FutureProvider.autoDispose
    .family<ServiceEntity?, TimetableKey>(
      (ref, key) => ref
          .watch(journeyRepositoryProvider)
          .timetable(key.id, key.date, regular: key.regular),
      retry: (_, _) => null,
    );

typedef DateTrips = ({String date, String ids});
final journeyUpdatesProvider = StreamProvider.autoDispose
    .family<List<DailyAdjustment>, DateTrips>((ref, key) {
      final ids = (jsonDecode(key.ids) as List).cast<String>();
      if (ids.isEmpty) return Stream.value([]);
      return ref
          .watch(tripRepositoryProvider)
          .watchAdjustments(key.date, tripIds: ids);
    }, retry: (_, _) => null);
typedef JourneyFeed = ({
  List<ServiceEntity> rows,
  bool sample,
  bool stale,
  bool updatesMissing,
  bool more,
});
final journeyFeedProvider = Provider.autoDispose
    .family<AsyncValue<JourneyFeed>, DepartureQuery>((ref, q) {
      if (ref.watch(passengerPagingEnabledProvider)) {
        return ref
            .watch(pagedDeparturesProvider(q))
            .whenData(
              (p) => (
                rows: p.records,
                sample: false,
                stale: p.cached,
                updatesMissing: p.cached || p.error != null,
                more: p.cursor != null,
              ),
            );
      }
      final catalog = ref.watch(serviceCatalogProvider);
      return catalog.whenData((data) {
        final day = DateTime.parse(q.date);
        final index = ref.watch(serviceIndexProvider).requireValue;
        final rows = q.directory
            ? index.directory(q.from)
            : index.search(
                from: q.from,
                to: q.to,
                filterDay: weekDays[day.weekday - 1],
                onlyRunningToday: false,
                today: weekDays[day.weekday - 1],
              );
        final ids =
            rows
                .where((s) => s.busId.isNotEmpty && !data.isDemo)
                .map((s) => s.id)
                .toList()
              ..sort();
        final daily = q.directory || ids.isEmpty
            ? const AsyncData(<DailyAdjustment>[])
            : ref.watch(
                journeyUpdatesProvider((date: q.date, ids: jsonEncode(ids))),
              );
        final changes = {
          for (final d in daily.asData?.value ?? <DailyAdjustment>[])
            d.tripId: d,
        };
        return (
          rows: orderDepartures([
            for (final row in rows) changes[row.id]?.apply(row) ?? row,
          ], q.from),
          sample: data.isDemo,
          stale: data.cached,
          updatesMissing: daily.hasError || data.cached || data.unavailable,
          more: false,
        );
      });
    });

final scheduleReminderProvider = Provider((ref) => DepartureReminder.schedule);
