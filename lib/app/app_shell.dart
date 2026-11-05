import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../core/constants/colors.dart';
import '../features/passenger/presentation/pages/passenger_page.dart';
import '../features/routes/presentation/pages/routes_page.dart';
import '../features/owner/presentation/pages/owner_page.dart';
import '../features/tracking/presentation/pages/tracking_page.dart';
import '../features/crew/presentation/pages/crew_page.dart';
import 'navigation_provider.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key});
  static const _labels = ['Find bus', 'Routes', 'Owner', 'Tracking', 'Crew'];
  static const _icons = [
    Icons.directions_bus_outlined,
    Icons.alt_route,
    Icons.business_outlined,
    Icons.location_on_outlined,
    Icons.badge_outlined,
  ];
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
    void select(int i) =>
        ref.read(navigationProvider.notifier).select(AppTab.values[i]);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1000;
        return Scaffold(
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(72),
            child: Material(
              color: Colors.white,
              child: SafeArea(
                bottom: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        height: 72,
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.directions_bus_outlined,
                                color: Colors.white,
                                size: 23,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: wide ? 0 : 1,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'FindMyBus',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -.4,
                                    ),
                                  ),
                                  if (!wide)
                                    Text(
                                      _labels[tab.index],
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (wide) ...[
                              const SizedBox(width: 24),
                              for (var i = 0; i < _labels.length; i++)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                  ),
                                  child: tab.index == i
                                      ? FilledButton(
                                          onPressed: () => select(i),
                                          child: Text(_labels[i]),
                                        )
                                      : TextButton(
                                          onPressed: () => select(i),
                                          child: Text(_labels[i]),
                                        ),
                                ),
                              const Spacer(),
                              const Text(
                                'Kerala transit',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 16),
                            ],
                            IconButton.filled(
                              tooltip: 'Owner account',
                              onPressed: () => select(AppTab.owner.index),
                              icon: const Icon(Icons.person_outline, size: 21),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          body: SafeArea(top: false, bottom: false, child: page),
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: tab.index,
                  onDestinationSelected: select,
                  destinations: [
                    for (var i = 0; i < _labels.length; i++)
                      NavigationDestination(
                        icon: Icon(_icons[i]),
                        label: _labels[i],
                      ),
                  ],
                ),
        );
      },
    );
  }
}
