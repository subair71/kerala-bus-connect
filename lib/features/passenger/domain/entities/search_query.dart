import 'package:equatable/equatable.dart';

class SearchQuery extends Equatable {
  final String from;
  final String to;
  final String filterDay;
  final bool onlyRunningToday;
  final DateTime? serviceDate;

  const SearchQuery({
    this.from = 'Aluva',
    this.to = 'Kaloor',
    this.filterDay = 'All Days',
    this.onlyRunningToday = false,
    this.serviceDate,
  });

  SearchQuery copyWith({
    String? from,
    String? to,
    String? filterDay,
    bool? onlyRunningToday,
    DateTime? serviceDate,
    bool clearDate = false,
  }) {
    return SearchQuery(
      serviceDate: clearDate ? null : serviceDate ?? this.serviceDate,
      from: from ?? this.from,
      to: to ?? this.to,
      filterDay: filterDay ?? this.filterDay,
      onlyRunningToday: onlyRunningToday ?? this.onlyRunningToday,
    );
  }

  @override
  List<Object?> get props => [from, to, filterDay, onlyRunningToday, serviceDate];
}
