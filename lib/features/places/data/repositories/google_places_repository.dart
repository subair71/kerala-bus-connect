import '../../domain/entities/place_prediction.dart';
import '../../domain/repositories/places_repository.dart';

typedef PlaceRequest = Future<Object?> Function(String input);

/// Only the server proxy talks to Google; no Maps web-service key in the app.
class GooglePlacesRepository implements PlacesRepository {
  final PlaceRequest request;
  const GooglePlacesRepository(this.request);

  @override
  Future<List<PlacePrediction>> suggest(String input) async {
    final term = input.trim();
    if (term.runes.length < 3 || term.length > 120) return const [];
    final response = await request(term).timeout(const Duration(seconds: 8));
    if (response is! Map || response['suggestions'] is! List) {
      throw const FormatException('Invalid place suggestions');
    }
    final results = <PlacePrediction>[];
    for (final item in (response['suggestions'] as List).take(5)) {
      if (item is! Map) continue;
      final id = item['id'];
      final name = item['name'];
      final address = item['address'];
      if (id is! String ||
          id.isEmpty ||
          name is! String ||
          name.trim().isEmpty) {
        continue;
      }
      results.add(
        PlacePrediction(
          id: id,
          name: name.trim(),
          address: address is String ? address : '',
        ),
      );
    }
    return List.unmodifiable(results);
  }
}
