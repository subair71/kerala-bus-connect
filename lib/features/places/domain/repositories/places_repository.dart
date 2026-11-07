import '../entities/place_prediction.dart';

abstract interface class PlacesRepository {
  Future<List<PlacePrediction>> suggest(String input);
}
