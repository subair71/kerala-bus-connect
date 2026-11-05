import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/time_utils.dart';
import 'search_state.dart';

class SearchCubit extends Cubit<SearchState> {
  SearchCubit() : super(SearchState(filterDay: todayName()));

  void updateFrom(String from) => emit(state.copyWith(from: from));

  void updateTo(String to) => emit(state.copyWith(to: to));

  void swapFromAndTo() => emit(state.copyWith(from: state.to, to: state.from));

  void setFilterDay(String day) => emit(state.copyWith(filterDay: day));

  void toggleOnlyRunningToday(bool value) =>
      emit(state.copyWith(onlyRunningToday: value));

  void selectPopularDestination(String stop) => emit(state.copyWith(to: stop));
}
