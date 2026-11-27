import 'package:hooks_riverpod/hooks_riverpod.dart';

enum AppTab {
  passenger,
  departures,
  routes,
  saved,
  more,
  owner,
  tracking,
  crew,
}

final navigationProvider = NotifierProvider<NavigationController, AppTab>(
  NavigationController.new,
);

class NavigationController extends Notifier<AppTab> {
  @override
  AppTab build() => AppTab.passenger;
  void select(AppTab tab) => state = tab;
}
