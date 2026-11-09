/// A complete source selection. Live and sample rows are never combined.
class DataSet<T> {
  final List<T> records;
  final bool isDemo;
  final bool unavailable;
  final bool cached;
  DataSet(
    Iterable<T> records, {
    this.isDemo = false,
    this.unavailable = false,
    this.cached = false,
  }) : records = List.unmodifiable(records);
}
