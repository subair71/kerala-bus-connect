import 'dart:async';
import 'dart:convert';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/config/firebase_config.dart';
import '../../../../core/providers/cache_lifetime.dart';
import '../../../platform/presentation/providers/platform_providers.dart';
import '../../../timetables/data/models/service_model.dart';
import '../../../timetables/domain/entities/service_entity.dart';
import '../../../trips/domain/entities/trip_plan.dart';
import '../../data/public_page_cache.dart';
import 'search_providers.dart';

typedef DepartureQuery = ({String from, String to, String date, bool directory});
class DeparturePage {
  final List<ServiceEntity> records;
  final Object? cursor;
  final bool loadingMore, cached;
  final String? error;
  const DeparturePage(this.records, {this.cursor, this.loadingMore = false,
    this.cached = false, this.error});
}
final publicPageCacheProvider = Provider((ref) => PublicPageCache(firebaseOptions.projectId));
final currentDepartureQueryProvider = Provider.autoDispose<DepartureQuery>((ref) {
  final query = ref.watch(debouncedSearchProvider);
  return (from: query.from, to: query.to,
    date: serviceDateKey(query.serviceDate ?? ref.watch(journeyTodayProvider)),
    directory: false);
});
final pagedDeparturesProvider = AsyncNotifierProvider.autoDispose
    .family<PagedDepartures, DeparturePage, DepartureQuery>(PagedDepartures.new);
class PagedDepartures extends AsyncNotifier<DeparturePage> {
  PagedDepartures(this.query);
  final DepartureQuery query;
  bool _busy = false;
  String get _key => jsonEncode([query.from, query.to, query.date, query.directory]);
  @override
  Future<DeparturePage> build() async {
    retainWhileIdle(ref, const Duration(seconds: 60));
    final cached = await ref.watch(publicPageCacheProvider).read(_key);
    if (cached != null) {
      unawaited(Future(() => refresh()));
      return DeparturePage(_decode(cached['records'] as List,
        cachedAt: DateTime.parse(cached['at'] as String)), cached: true);
    }
    return _fetch();
  }
  List<ServiceEntity> _decode(List<dynamic> rows, {DateTime? cachedAt}) => [
    for (final raw in rows)
      (() {
        final data = Map<String, dynamic>.from(raw as Map);
        final service = ServiceModel.fromMap(data['id'] as String, data, cachedAt: cachedAt);
        if (cachedAt != null || data['serviceDate'] == null) return service;
        return service.withExpected(
          Map<String, int>.from(data['expectedStopTimings'] as Map? ?? {}),
          data['serviceDate'] as String,
          status: RunningStatus.parse(data['runningStatus']));
      })(),
  ];
  Future<DeparturePage> _fetch({Object? cursor, List<ServiceEntity> previous = const []}) async {
    final result = await ref.read(platformRepositoryProvider).call('searchTimetables',
      {'from': query.from, 'to': query.to, 'date': query.date,
        'directory': query.directory, 'cursor': cursor});
    final raw = result['records'] as List;
    if (cursor == null) unawaited(ref.read(publicPageCacheProvider).write(_key, raw));
    final records = <ServiceEntity>[...previous];
    final seen = records.map((s) => '${s.id}:${s.serviceDate}').toSet();
    for (final row in _decode(raw)) {
      if (seen.add('${row.id}:${row.serviceDate}')) records.add(row);
    }
    return DeparturePage(List.unmodifiable(records), cursor: result['cursor']);
  }
  Future<void> refresh() async {
    if (_busy || !ref.mounted) return;
    _busy = true;
    final previous = state.asData?.value;
    try {
      final page = await _fetch();
      if (ref.mounted) state = AsyncData(page);
    } catch (error, stack) {
      if (ref.mounted) state = previous == null ? AsyncError(error, stack) :
        AsyncData(DeparturePage(previous.records, cached: previous.cached,
          cursor: previous.cursor, error: 'Unable to refresh. Saved timings may be outdated.'));
    } finally { _busy = false; }
  }
  Future<void> next() async {
    final current = state.asData?.value;
    if (_busy || current == null || current.cursor == null || current.cached) return;
    _busy = true;
    state = AsyncData(DeparturePage(current.records, cursor: current.cursor, loadingMore: true));
    try {
      final page = await _fetch(cursor: current.cursor, previous: current.records);
      if (ref.mounted) state = AsyncData(page);
    } catch (_) {
      if (ref.mounted) state = AsyncData(DeparturePage(current.records,
        cursor: current.cursor, error: 'Unable to load more. Retry when connected.'));
    } finally { _busy = false; }
  }
}
