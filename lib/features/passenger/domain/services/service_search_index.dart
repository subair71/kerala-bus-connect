import '../../../timetables/domain/entities/service_entity.dart';

/// Normalizes and sorts a snapshot once, rather than on every search keystroke.
class ServiceSearchIndex {
  final List<_IndexedService> _services;
  (String, String, String, bool, String)? _lastSearch;
  List<ServiceEntity> _searchResults = const [];
  String? _lastDirectoryQuery;
  List<ServiceEntity> _directoryResults = const [];

  ServiceSearchIndex(List<ServiceEntity> services)
      : _services = services.map(_IndexedService.new).toList()
          ..sort((a, b) =>
              a.service.departureMinutes.compareTo(b.service.departureMinutes));

  List<ServiceEntity> search({
    required String from,
    required String to,
    required String filterDay,
    required bool onlyRunningToday,
    required String today,
  }) {
    final fromTerm = from.trim().toLowerCase();
    final toTerm = to.trim().toLowerCase();
    final key = (fromTerm, toTerm, filterDay, onlyRunningToday, today);
    if (key == _lastSearch) return _searchResults;
    _lastSearch = key;
    _searchResults = List.unmodifiable([
      for (final entry in _services)
        if ((!onlyRunningToday || !entry.service.offDays.contains(today)) &&
            (filterDay == 'All Days' ||
                !entry.service.offDays.contains(filterDay)) &&
            entry.matchesStops(fromTerm, toTerm))
          entry.service,
    ]);
    return _searchResults;
  }

  List<ServiceEntity> directory(String query) {
    final term = query.trim().toLowerCase();
    if (term == _lastDirectoryQuery) return _directoryResults;
    _lastDirectoryQuery = term;
    _directoryResults = List.unmodifiable([
      for (final entry in _services)
        if (term.isEmpty ||
            entry.routeName.contains(term) ||
            entry.stops.any((stop) => stop.contains(term)))
          entry.service,
    ]);
    return _directoryResults;
  }
}

class _IndexedService {
  final ServiceEntity service;
  final String routeName;
  final List<String> stops;

  _IndexedService(this.service)
      : routeName = service.routeName.toLowerCase(),
        stops = service.stops.map((stop) => stop.toLowerCase()).toList();

  bool matchesStops(String from, String to) {
    if (from.isEmpty && to.isEmpty) return true;
    final fromIndex =
        from.isEmpty ? -1 : stops.indexWhere((stop) => stop.contains(from));
    final toIndex =
        to.isEmpty ? -1 : stops.indexWhere((stop) => stop.contains(to));
    if (from.isNotEmpty && fromIndex == -1) return false;
    if (to.isNotEmpty && toIndex == -1) return false;
    return from.isEmpty || to.isEmpty || fromIndex < toIndex;
  }
}
