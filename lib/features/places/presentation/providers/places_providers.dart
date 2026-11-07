import 'dart:async';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../timetables/presentation/providers/timetable_providers.dart';
import '../../data/datasources/firebase_places_client.dart';
import '../../data/repositories/google_places_repository.dart';
import '../../domain/repositories/places_repository.dart';
import '../../domain/services/stop_labels.dart';

final googlePlacesEnabledProvider = Provider<bool>(
  (ref) => const bool.fromEnvironment('GOOGLE_PLACES_ENABLED'),
);
final placesRepositoryProvider = Provider<PlacesRepository>((ref) {
  final client = FirebasePlacesClient(
    region: const String.fromEnvironment(
      'GOOGLE_PLACES_REGION',
      defaultValue: 'asia-south1',
    ),
    webSiteKey: const String.fromEnvironment('FIREBASE_APP_CHECK_WEB_SITE_KEY'),
  );
  return GooglePlacesRepository(client.suggest);
});
final placeDebounceProvider = Provider<Duration>(
  (ref) => const Duration(milliseconds: 350),
);
final stopLabelsProvider = Provider.autoDispose<StopLabels>((ref) {
  final services = ref.watch(serviceCatalogProvider).asData?.value.records;
  return StopLabels(services?.expand((s) => s.stops) ?? const []);
});

enum PlaceSource { typed, timetable, google }

class PlaceOption {
  final String value, title, subtitle;
  final PlaceSource source;
  const PlaceOption(this.value, this.title, this.subtitle, this.source);
}

class PlaceSearchState {
  final String query;
  final bool loading, unavailable;
  const PlaceSearchState({
    this.query = '',
    this.loading = false,
    this.unavailable = false,
  });
}

/// Each field has its own debounce and request generation. Results are transient.
final placeSearchProvider = NotifierProvider.autoDispose
    .family<PlaceSearch, PlaceSearchState, Object>(PlaceSearch.new);

class PlaceSearch extends Notifier<PlaceSearchState> {
  PlaceSearch(this.identity);
  final Object identity;
  Timer? _timer;
  Completer<List<PlaceOption>>? _pending;
  int _generation = 0;

  @override
  PlaceSearchState build() {
    ref.onDispose(_cancel);
    return const PlaceSearchState();
  }

  void _cancel() {
    _generation++;
    _timer?.cancel();
    final pending = _pending;
    if (pending != null && !pending.isCompleted) pending.complete(const []);
    _pending = null;
  }

  void dismiss() {
    _cancel();
    state = const PlaceSearchState();
  }

  Future<List<PlaceOption>> search(StopInput input) {
    _cancel();
    final query = input.query;
    if (query.runes.length < 2 || query.length > 120) {
      state = const PlaceSearchState();
      return Future.value(const []);
    }
    final enabled =
        ref.read(googlePlacesEnabledProvider) && query.runes.length >= 3;
    state = PlaceSearchState(query: query, loading: enabled);
    final generation = _generation;
    final pending = Completer<List<PlaceOption>>();
    _pending = pending;
    final delay = enabled ? ref.read(placeDebounceProvider) : Duration.zero;
    _timer = Timer(delay, () async {
      final labels = ref.read(stopLabelsProvider);
      final options = <PlaceOption>[
        PlaceOption(
          input.text,
          'Use “$query”',
          'Keep the entered stop name',
          PlaceSource.typed,
        ),
        for (final name in labels.matching(query))
          PlaceOption(
            input.replace(name),
            name,
            'Timetable stop',
            PlaceSource.timetable,
          ),
      ];
      var unavailable = false;
      if (enabled) {
        try {
          final predictions = await ref
              .read(placesRepositoryProvider)
              .suggest(query);
          final seen = options
              .skip(1)
              .map((o) => o.title.toLowerCase())
              .toSet();
          for (final prediction in predictions) {
            final name = labels.canonical(prediction.name);
            // Keep Google alternatives with different addresses, but prefer an
            // identical timetable label when it exists.
            if (seen.contains(name.toLowerCase())) continue;
            options.add(
              PlaceOption(
                input.replace(name),
                name,
                prediction.address,
                PlaceSource.google,
              ),
            );
          }
        } catch (_) {
          unavailable = true;
        }
      }
      if (!ref.mounted || generation != _generation) return;
      state = PlaceSearchState(query: query, unavailable: unavailable);
      _pending = null;
      pending.complete(List.unmodifiable(options));
    });
    return pending.future;
  }
}
