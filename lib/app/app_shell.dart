import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../core/constants/colors.dart';
import '../core/theme/home_theme.dart';
import '../features/passenger/presentation/widgets/transit_advisory.dart';
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
    final home = tab == AppTab.passenger;
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
        final headerHeight = scale > 1.5 ? 92.0 : 68.0;
        return Theme(
          data: home ? HomeTheme.from(Theme.of(context)) : Theme.of(context),
          child: Scaffold(
            appBar: PreferredSize(
              preferredSize: Size.fromHeight(headerHeight),
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
                          height: headerHeight,
                          child: Row(
                            children: [
                              const ExcludeSemantics(child: _BrandMark()),
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
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                        letterSpacing: -.6,
                                      ),
                                    ),
                                    Text(
                                      home || wide ? 'Kerala Transit' : _labels[tab.index],
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
                                    padding: const EdgeInsets.symmetric(horizontal: 3),
                                    child: TextButton.icon(
                                      style: TextButton.styleFrom(
                                        foregroundColor: tab.index == i
                                            ? AppColors.accentInk
                                            : AppColors.onSurfaceVariant,
                                        backgroundColor: tab.index == i
                                            ? AppColors.secondaryContainer
                                            : null,
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                      ),
                                      onPressed: () => select(i),
                                      icon: Icon(_icons[i], size: 19),
                                      label: Text(_labels[i]),
                                    ),
                                  ),
                                const SizedBox(width: 24),
                              ],
                              if (home)
                                IconButton(
                                  tooltip: 'Transit advisory',
                                  onPressed: () => showTransitAdvisory(context),
                                  icon: const Icon(
                                    Icons.notifications_none_outlined,
                                    size: 23,
                                    color: AppColors.onSurface,
                                  ),
                                ),
                              IconButton(
                                tooltip: 'Owner account',
                                onPressed: () => select(AppTab.owner.index),
                                padding: EdgeInsets.zero,
                                icon: const CircleAvatar(
                                  radius: 17,
                                  backgroundColor: AppColors.primary,
                                  child: Icon(Icons.person_outline, size: 19, color: Colors.white),
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
            body: SafeArea(top: false, bottom: false, child: page),
            bottomNavigationBar: wide
                ? null
                : NavigationBar(
                    selectedIndex: tab.index,
                    onDestinationSelected: select,
                    destinations: [
                      for (var i = 0; i < _labels.length; i++)
                        NavigationDestination(
                          icon: Icon(_icons[i], size: 22, color: AppColors.onSurfaceVariant),
                          selectedIcon: Icon(_icons[i], size: 22, color: AppColors.primary),
                          label: _labels[i],
                        ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();
  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 30,
    height: 34,
    child: ColoredBox(
      color: Colors.white,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.directions_bus_outlined, size: 20, color: AppColors.primary),
          SizedBox(height: 1),
          Text(
            'FindMyBus',
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              fontSize: 4,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    ),
  );
}
