import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../core/constants/colors.dart';
import '../core/widgets/app_components.dart';
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
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final wide = constraints.maxWidth >= 1000 && scale <= 1.3;
        final headerHeight = scale > 1.5 ? 92.0 : 76.0;
        return Scaffold(
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(headerHeight),
            child: Material(
              color: Colors.white,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          height: headerHeight,
                          child: Row(
                            children: [
                              const AppIconTile(
                                Icons.directions_bus_outlined,
                                size: 40,
                                emphasized: true,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: wide ? 0 : 1,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'FindMyBus',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -.6,
                                      ),
                                    ),
                                    Text(
                                      wide
                                          ? 'Kerala transit'
                                          : _labels[tab.index],
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (wide) ...[
                                const Spacer(),
                                for (var i = 0; i < _labels.length; i++)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 3,
                                    ),
                                    child: TextButton.icon(
                                      style: TextButton.styleFrom(
                                        foregroundColor: tab.index == i
                                            ? AppColors.primary
                                            : AppColors.onSurfaceVariant,
                                        backgroundColor: tab.index == i
                                            ? AppColors.secondaryContainer
                                            : null,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                        ),
                                      ),
                                      onPressed: () => select(i),
                                      icon: Icon(_icons[i], size: 19),
                                      label: Text(_labels[i]),
                                    ),
                                  ),
                                const SizedBox(width: 24),
                              ],
                              IconButton.outlined(
                                tooltip: 'Owner account',
                                style: IconButton.styleFrom(
                                  foregroundColor: AppColors.onSurface,
                                  side: const BorderSide(
                                    color: AppColors.border,
                                  ),
                                ),
                                onPressed: () => select(AppTab.owner.index),
                                icon: const Icon(
                                  Icons.person_outline,
                                  size: 22,
                                ),
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
          ),
          body: SafeArea(top: false, bottom: false, child: page),
          bottomNavigationBar: wide
              ? null
              : SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: Material(
                      color: Colors.white,
                      elevation: 0,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: NavigationBar(
                        selectedIndex: tab.index,
                        onDestinationSelected: select,
                        destinations: [
                          for (var i = 0; i < _labels.length; i++)
                            NavigationDestination(
                              icon: Icon(
                                _icons[i],
                                color: AppColors.onSurfaceVariant,
                              ),
                              selectedIcon: Icon(
                                _icons[i],
                                color: AppColors.primary,
                              ),
                              label: _labels[i],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }
}
