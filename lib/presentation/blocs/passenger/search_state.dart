import 'package:equatable/equatable.dart';

class SearchState extends Equatable {
  final String from;
  final String to;
  final String filterDay;
  final bool onlyRunningToday;

  const SearchState({
    this.from = 'Aluva',
    this.to = 'Kaloor',
    this.filterDay = 'All Days',
    this.onlyRunningToday = false,
  });

  SearchState copyWith({
    String? from,
    String? to,
    String? filterDay,
    bool? onlyRunningToday,
  }) {
    return SearchState(
      from: from ?? this.from,
      to: to ?? this.to,
      filterDay: filterDay ?? this.filterDay,
      onlyRunningToday: onlyRunningToday ?? this.onlyRunningToday,
    );
  }

  @override
  List<Object?> get props => [from, to, filterDay, onlyRunningToday];
}
