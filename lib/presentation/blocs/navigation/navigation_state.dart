import 'package:equatable/equatable.dart';

enum AppTab { timetables, liveTrack, routes, dutyRoster, ownersPortal }

class NavigationState extends Equatable {
  final AppTab currentTab;

  const NavigationState({this.currentTab = AppTab.timetables});

  bool get isOwnerMode => currentTab == AppTab.ownersPortal;

  @override
  List<Object?> get props => [currentTab];
}
