/// A complete source selection. Live and sample rows are never combined.
class DataSet<T> {
  final List<T> records;
  final bool isDemo;
  final bool unavailable;
  DataSet(Iterable<T> records, {this.isDemo = false, this.unavailable = false})
      : records = List.unmodifiable(records);
}
