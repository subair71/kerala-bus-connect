import 'package:flutter_bloc/flutter_bloc.dart';
import 'navigation_state.dart';

class NavigationCubit extends Cubit<NavigationState> {
  NavigationCubit() : super(const NavigationState());

  void setTab(AppTab tab) => emit(NavigationState(currentTab: tab));

  void togglePassengerOwner(bool isOwner) {
    if (isOwner) {
      emit(const NavigationState(currentTab: AppTab.ownersPortal));
    } else {
      emit(const NavigationState(currentTab: AppTab.timetables));
    }
  }
}
