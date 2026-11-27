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
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/providers/firebase_providers.dart';
import '../../../timetables/data/models/service_model.dart';
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
  final _prefs = SharedPreferencesAsync();
  Future<void> _pending = Future.value();
  static const _key = 'findmybus.journeys.v1';
  @override
  Future<List<SavedJourney>> build() async {
    final raw = await _prefs.getString(_key);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map(
          (row) => SavedJourney.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

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
      await _prefs.setString(
        _key,
        jsonEncode(rows.map((e) => e.toJson()).toList()),
      );
      if (ref.mounted) state = AsyncData(List.unmodifiable(rows));
    });
    _pending = operation.catchError((Object _) {});
    return operation;
  }
}

final sampleCatalogueProvider =
    FutureProvider.autoDispose<({List<ServiceEntity> records, bool cloud})>((
      ref,
    ) async {
      try {
        final docs = await ref
            .watch(firestoreProvider)
            .collection('sample_services')
            .get()
            .timeout(const Duration(seconds: 5));
        final rows = docs.docs
            .where(
              (d) => d.id.startsWith('demo:') && d.data()['sample'] == true,
            )
            .map(ServiceModel.fromSnapshot)
            .toList();
        if (rows.isNotEmpty) return (records: rows, cloud: true);
      } catch (_) {
        /* The bundled copy keeps the explicitly opened sample catalogue usable offline. */
      }
      final rows =
          jsonDecode(
                await rootBundle.loadString('assets/samples/services.json'),
              )
              as List;
      return (
        records: [
          for (final row in rows)
            ServiceModel.fromMap(
              row['id'] as String,
              Map<String, dynamic>.from(row as Map),
            ),
        ],
        cloud: false,
      );
    });

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
      if (ref.watch(platformEnabledProvider)) {
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
