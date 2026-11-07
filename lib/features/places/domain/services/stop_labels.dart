/// Published timetable labels remain the authority for schedule matching.
class StopLabels {
  final Map<String, String> _labels;
  StopLabels(Iterable<String> labels)
    : _labels = {
        for (final label in labels)
          if (label.trim().isNotEmpty) label.trim().toLowerCase(): label.trim(),
      };

  String canonical(String name) => _labels[name.trim().toLowerCase()] ?? name;
  List<String> matching(String query) {
    final term = query.trim().toLowerCase();
    final matches = _labels.entries.where((e) => e.key.contains(term)).toList();
    matches.sort((a, b) {
      final prefix = (a.key.startsWith(term) ? 0 : 1)
          .compareTo(b.key.startsWith(term) ? 0 : 1);
      return prefix != 0 ? prefix : a.key.compareTo(b.key);
    });
    return matches.take(4).map((e) => e.value).toList(growable: false);
  }
}

/// Edit only the comma-delimited stop at the caret, preserving the other stops.
class StopInput {
  final String text, query;
  final int start, end;
  const StopInput._(this.text, this.query, this.start, this.end);
  factory StopInput(String text, int cursor, {bool multiple = false}) {
    if (!multiple) return StopInput._(text, text.trim(), 0, text.length);
    final caret = cursor.clamp(0, text.length);
    final start = caret == 0 ? 0 : text.lastIndexOf(',', caret - 1) + 1;
    final comma = text.indexOf(',', caret);
    final end = comma < 0 ? text.length : comma;
    return StopInput._(text, text.substring(start, end).trim(), start, end);
  }
  String replace(String label) {
    final clean = label.replaceAll(',', ' ').trim();
    return text.replaceRange(start, end, '${start == 0 ? '' : ' '}$clean');
  }
}
