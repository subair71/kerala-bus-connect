import 'dart:async';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kerala_bus_connect/features/places/data/repositories/google_places_repository.dart';
import 'package:kerala_bus_connect/features/places/domain/entities/place_prediction.dart';
import 'package:kerala_bus_connect/features/places/domain/repositories/places_repository.dart';
import 'package:kerala_bus_connect/features/places/domain/services/stop_labels.dart';
import 'package:kerala_bus_connect/features/places/presentation/providers/places_providers.dart';

class FakePlaces implements PlacesRepository {
  final requests = <String>[];
  final pending = <Completer<List<PlacePrediction>>>[];
  @override
  Future<List<PlacePrediction>> suggest(String input) {
    requests.add(input);
    final result = Completer<List<PlacePrediction>>();
    pending.add(result);
    return result.future;
  }
}

void main() {
  test(
    'canonical matching preserves real stop labels without fuzzy substitutions',
    () {
      final labels = StopLabels(['Aluva', 'Kaloor', 'Aluva Metro']);
      expect(labels.canonical('aluva'), 'Aluva');
      expect(labels.canonical('Aluva Bus Stand'), 'Aluva Bus Stand');
      expect(labels.matching('alu'), ['Aluva', 'Aluva Metro']);
    },
  );
  test('comma-separated input replaces only the stop at the caret', () {
    expect(
      StopInput('Aluva, Eda, Kaloor', 9, multiple: true).replace('Edappally'),
      'Aluva, Edappally, Kaloor',
    );
    expect(
      StopInput('Aluva, ', 7, multiple: true).replace('Kaloor'),
      'Aluva, Kaloor',
    );
    expect(StopInput(' Alu ', 3).replace('Aluva'), 'Aluva');
  });
  test(
    'repository handles empty/missing display fields, bounds and bad payloads',
    () async {
      var calls = 0;
      final repository = GooglePlacesRepository((input) async {
        calls++;
        return {
          'suggestions': [
            {'id': 'p1', 'name': ' Aluva ', 'address': null},
            {'id': '', 'name': 'missing id'},
            {'id': 'p2', 'name': false},
          ],
        };
      });
      expect(await repository.suggest('al'), isEmpty);
      expect(calls, 0);
      final result = await repository.suggest('Aluva');
      expect(result.single.name, 'Aluva');
      expect(result.single.address, '');
      expect(
        await GooglePlacesRepository(
          (_) async => {'suggestions': []},
        ).suggest('Aluva'),
        isEmpty,
      );
      await expectLater(
        GooglePlacesRepository((_) async => false).suggest('Aluva'),
        throwsFormatException,
      );
    },
  );
  test(
    'debounces rapid typing, drops stale responses, and recovers after errors',
    () {
      fakeAsync((clock) {
        final fake = FakePlaces();
        final container = ProviderContainer(
          overrides: [
            googlePlacesEnabledProvider.overrideWithValue(true),
            placesRepositoryProvider.overrideWithValue(fake),
            stopLabelsProvider.overrideWithValue(
              StopLabels(['Aluva', 'Kaloor']),
            ),
          ],
        );
        final provider = placeSearchProvider(Object());
        final subscription = container.listen(provider, (_, _) {});
        final controller = container.read(provider.notifier);
        controller.search(StopInput('Alu', 3));
        clock.elapse(const Duration(milliseconds: 200));
        controller.search(StopInput('Aluva', 5));
        clock.elapse(const Duration(milliseconds: 350));
        expect(fake.requests, ['Aluva']);
        List<PlaceOption>? latest;
        controller
            .search(StopInput('Kaloor', 6))
            .then((value) => latest = value);
        clock.elapse(const Duration(milliseconds: 350));
        fake.pending[0].complete(const [
          PlacePrediction(id: 'old', name: 'Old place'),
        ]);
        clock.flushMicrotasks();
        expect(latest, isNull);
        fake.pending[1].completeError(StateError('offline'));
        clock.flushMicrotasks();
        expect(latest!.any((o) => o.title == 'Kaloor'), isTrue);
        expect(container.read(provider).unavailable, isTrue);
        controller
            .search(StopInput('Edappally', 9))
            .then((value) => latest = value);
        clock.elapse(const Duration(milliseconds: 350));
        fake.pending[2].complete(const [
          PlacePrediction(id: 'new', name: 'Edappally', address: 'Kochi'),
        ]);
        clock.flushMicrotasks();
        expect(latest!.last.source, PlaceSource.google);
        expect(container.read(provider).unavailable, isFalse);
        subscription.close();
        container.dispose();
      });
    },
  );
  test(
    'disabled Google, short queries, focus loss and disposal make no API requests',
    () {
      fakeAsync((clock) {
        final fake = FakePlaces();
        final container = ProviderContainer(
          overrides: [
            googlePlacesEnabledProvider.overrideWithValue(false),
            placesRepositoryProvider.overrideWithValue(fake),
            stopLabelsProvider.overrideWithValue(StopLabels(['Aluva'])),
          ],
        );
        final provider = placeSearchProvider(Object());
        final sub = container.listen(provider, (_, _) {});
        final controller = container.read(provider.notifier);
        List<PlaceOption>? result;
        controller.search(StopInput('Alu', 3)).then((v) => result = v);
        clock.elapse(Duration.zero);
        clock.flushMicrotasks();
        expect(result!.last.title, 'Aluva');
        expect(fake.requests, isEmpty);
        sub.close();
        container.dispose();

        final enabled = ProviderContainer(
          overrides: [
            googlePlacesEnabledProvider.overrideWithValue(true),
            placesRepositoryProvider.overrideWithValue(fake),
            stopLabelsProvider.overrideWithValue(StopLabels([])),
          ],
        );
        final active = enabled.listen(provider, (_, _) {});
        final search = enabled.read(provider.notifier);
        search.search(StopInput('a', 1));
        clock.elapse(const Duration(seconds: 1));
        search.search(StopInput('Aluva', 5));
        search.dismiss();
        clock.elapse(const Duration(seconds: 1));
        search.search(StopInput('Kaloor', 6));
        active.close();
        enabled.dispose();
        clock.elapse(const Duration(seconds: 1));
        expect(fake.requests, isEmpty);
      });
    },
  );
  test(
    'Google name and address are never concatenated into timetable queries',
    () {
      fakeAsync((clock) {
        final fake = FakePlaces();
        final container = ProviderContainer(
          overrides: [
            googlePlacesEnabledProvider.overrideWithValue(true),
            placesRepositoryProvider.overrideWithValue(fake),
            stopLabelsProvider.overrideWithValue(StopLabels([])),
          ],
        );
        final provider = placeSearchProvider(Object());
        final sub = container.listen(provider, (_, _) {});
        List<PlaceOption>? options;
        container
            .read(provider.notifier)
            .search(StopInput('Eda', 3))
            .then((v) => options = v);
        clock.elapse(const Duration(milliseconds: 350));
        fake.pending.single.complete(const [
          PlacePrediction(
            id: 'p',
            name: 'Edappally',
            address: 'Kochi, Kerala, India',
          ),
        ]);
        clock.flushMicrotasks();
        expect(options!.last.value, 'Edappally');
        expect(options!.last.subtitle, 'Kochi, Kerala, India');
        sub.close();
        container.dispose();
      });
    },
  );
}
