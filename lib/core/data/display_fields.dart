String displayText(Object? value, String placeholder) {
  final text = value is String ? value.trim() : '';
  return text.isEmpty ? placeholder : text;
}
List<String> stringList(Object? value) => value is List
    ? value.whereType<String>().where((s) => s.trim().isNotEmpty).toList()
    : [];
int? scheduleMinutes(Object? value) => value is num && value.isFinite &&
    value >= 0 && value < 2880 && value == value.toInt() ? value.toInt() : null;
