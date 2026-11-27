import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
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
import '../features/journeys/presentation/pages/discovery_pages.dart';
import '../features/auth/presentation/providers/auth_providers.dart';

class AppShell extends HookConsumerWidget {
  const AppShell({super.key});
  static const _labels = ['Find bus', 'Departures', 'Routes', 'Saved', 'More'];
  static const _icons = [
    Icons.map_outlined,
    Icons.departure_board_outlined,
    Icons.alt_route,
    Icons.bookmark_outline,
    Icons.more_horiz,
  ];
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Observe session changes even while cached owner queries are off screen.
    // A listener keeps auth current without rebuilding the shell on each event.
    ref.listen(authUserProvider, (_, _) {});
    final tab = ref.watch(navigationProvider);
    final navIndex = tab.index >= _labels.length
        ? AppTab.more.index
        : tab.index;
    final home = tab == AppTab.passenger;
    final baseTheme = Theme.of(context);
    final homeTheme = useMemoized(() => HomeTheme.from(baseTheme), [baseTheme]);
    final page = switch (tab) {
      AppTab.passenger => const PassengerPage(),
      AppTab.departures => const DeparturesPage(),
      AppTab.saved => const SavedPage(),
      AppTab.more => const MorePage(),
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
        final headerHeight = scale > 1.5
            ? 92.0
            : scale > 1.15
            ? 74.0
            : 54.0;
        return Theme(
          data: homeTheme,
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
                                        color: AppColors.onSurface,
                                        letterSpacing: -.6,
                                      ),
                                    ),
                                    Text(
                                      home || wide
                                          ? 'Kerala Transit'
                                          : tab.name[0].toUpperCase() +
                                                tab.name.substring(1),
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
                                    child: Semantics(
                                      identifier:
                                          'nav-${AppTab.values[i].name}',
                                      child: TextButton.icon(
                                        style: TextButton.styleFrom(
                                          foregroundColor: navIndex == i
                                              ? AppColors.accentInk
                                              : AppColors.onSurfaceVariant,
                                          backgroundColor: navIndex == i
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
                              if (wide || tab.index >= _labels.length)
                                IconButton(
                                  tooltip: 'Owner account',
                                  onPressed: () => ref
                                      .read(navigationProvider.notifier)
                                      .select(AppTab.owner),
                                  padding: EdgeInsets.zero,
                                  icon: const CircleAvatar(
                                    radius: 17,
                                    backgroundColor: AppColors.primary,
                                    child: Icon(
                                      Icons.person_outline,
                                      size: 19,
                                      color: Colors.white,
                                    ),
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
            body: SafeArea(
              top: false,
              bottom: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: page,
                ),
              ),
            ),
            bottomNavigationBar: wide
                ? null
                : NavigationBar(
                    selectedIndex: navIndex,
                    onDestinationSelected: select,
                    destinations: [
                      for (var i = 0; i < _labels.length; i++)
                        Semantics(
                          identifier: 'nav-${AppTab.values[i].name}',
                          child: NavigationDestination(
                            icon: Icon(
                              _icons[i],
                              size: 22,
                              color: AppColors.onSurfaceVariant,
                            ),
                            selectedIcon: Icon(
                              _icons[i],
                              size: 22,
                              color: AppColors.primary,
                            ),
                            label: _labels[i],
                          ),
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
  Widget build(BuildContext context) => Image.asset(
    'assets/images/findmybus-logo.jpg',
    width: 40,
    height: 33,
    fit: BoxFit.contain,
  );
}
