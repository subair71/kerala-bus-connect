import 'package:equatable/equatable.dart';

class SearchQuery extends Equatable {
  final String from;
  final String to;
  final String filterDay;
  final bool onlyRunningToday;

  const SearchQuery({
    this.from = 'Aluva',
    this.to = 'Kaloor',
    this.filterDay = 'All Days',
    this.onlyRunningToday = false,
  });

  SearchQuery copyWith({
    String? from,
    String? to,
    String? filterDay,
    bool? onlyRunningToday,
  }) {
    return SearchQuery(
      from: from ?? this.from,
      to: to ?? this.to,
      filterDay: filterDay ?? this.filterDay,
      onlyRunningToday: onlyRunningToday ?? this.onlyRunningToday,
    );
  }

  @override
  List<Object?> get props => [from, to, filterDay, onlyRunningToday];
}
