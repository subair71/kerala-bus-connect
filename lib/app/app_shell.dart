import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../features/passenger/presentation/pages/passenger_page.dart';
import '../features/routes/presentation/pages/routes_page.dart';
import '../features/owner/presentation/pages/owner_page.dart';
import '../features/tracking/presentation/pages/tracking_page.dart';
import '../features/crew/presentation/pages/crew_page.dart';
import 'navigation_provider.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key});
  static const _labels = ['Find bus', 'Routes', 'Owner', 'Tracking', 'Crew'];
  static const _icons = [Icons.search, Icons.alt_route, Icons.business, Icons.location_on, Icons.groups];
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(navigationProvider);
    final page = switch (tab) {
      AppTab.passenger => const PassengerPage(),
      AppTab.routes => const RoutesPage(),
      AppTab.owner => const OwnerPage(),
      AppTab.tracking => const TrackingPage(),
      AppTab.crew => const CrewPage(),
    };
    void select(int index) => ref.read(navigationProvider.notifier).select(AppTab.values[index]);
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 1000;
      return Scaffold(
        appBar: AppBar(title: const Text('FindMyBus'), centerTitle: false),
        body: Row(children: [
          if (wide) NavigationRail(selectedIndex: tab.index, onDestinationSelected: select,
            labelType: NavigationRailLabelType.all, destinations: [
              for (var i = 0; i < _labels.length; i++)
                NavigationRailDestination(icon: Icon(_icons[i]), label: Text(_labels[i])),
            ]),
          Expanded(child: page),
        ]),
        bottomNavigationBar: wide ? null : NavigationBar(selectedIndex: tab.index,
          onDestinationSelected: select, destinations: [
            for (var i = 0; i < _labels.length; i++)
              NavigationDestination(icon: Icon(_icons[i]), label: _labels[i]),
          ]),
      );
    });
  }
}
