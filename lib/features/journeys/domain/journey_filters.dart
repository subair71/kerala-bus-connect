import '../../timetables/domain/entities/service_entity.dart';

enum TimetableStatus { all, updated, scheduled }

class JourneyFilters {
  final int? after;
  final TimetableStatus status;
  final bool hideCancelled;
  const JourneyFilters({
    this.after,
    this.status = TimetableStatus.all,
    this.hideCancelled = false,
  });

  bool accepts(ServiceEntity service, String from) {
    final boarding = stopMatch(service, from, false);
    final time = service.expectedTime(boarding);
    final updated =
        service.runningStatus != RunningStatus.scheduled ||
        service.hasDailyAdjustment;
    return (after == null || (time != null && time >= after!)) &&
        (!hideCancelled || service.runningStatus != RunningStatus.cancelled) &&
        (status == TimetableStatus.all ||
            updated == (status == TimetableStatus.updated));
  }
}

String stopMatch(ServiceEntity service, String term, bool last) {
  if (term.trim().isEmpty)
    return (last ? service.stops.lastOrNull : service.stops.firstOrNull) ?? '';
  return service.stops
          .where((s) => s.toLowerCase().contains(term.trim().toLowerCase()))
          .firstOrNull ??
      '';
}

String clock24(int? m) {
  if (m == null || m < 0) return '—';
  final hh = ((m ~/ 60) % 24).toString().padLeft(2, '0');
  final mm = (m % 60).toString().padLeft(2, '0');
  return '$hh:$mm${m >= 1440 ? ' +${m ~/ 1440}d' : ''}';
}

class SavedJourney {
  final String kind, name, from, to, serviceId;
  final bool sampleCatalogue;
  const SavedJourney(
    this.kind,
    this.name, {
    this.from = '',
    this.to = '',
    this.serviceId = '',
    this.sampleCatalogue = false,
  });
  String get key => [kind, serviceId, from, to].join('|');
  Map<String, dynamic> toJson() => {
    'kind': kind,
    'name': name,
    'from': from,
    'to': to,
    'service': serviceId,
    'sampleCatalogue': sampleCatalogue,
  };
  factory SavedJourney.fromJson(Map<String, dynamic> m) => SavedJourney(
    m['kind'] as String,
    m['name'] as String,
    from: m['from'] as String,
    to: m['to'] as String,
    serviceId: m['service'] as String,
    sampleCatalogue: m['sampleCatalogue'] == true,
  );
}

DateTime boardingUtc(DateTime serviceDate, int minutes) => DateTime.utc(
  serviceDate.year,
  serviceDate.month,
  serviceDate.day,
).add(Duration(minutes: minutes - 330));
