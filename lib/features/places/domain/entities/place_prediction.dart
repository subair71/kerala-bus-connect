/// A transient suggestion. Google responses are never written to a catalogue.
class PlacePrediction {
  final String id, name, address;
  const PlacePrediction({
    required this.id,
    required this.name,
    this.address = '',
  });
}
