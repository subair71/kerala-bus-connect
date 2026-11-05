import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/constants/colors.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_event.dart';
import '../blocs/auth/auth_state.dart';
import '../blocs/navigation/navigation_cubit.dart';
import '../blocs/navigation/navigation_state.dart';
import 'crew_duty_roster_screen.dart';
import 'live_bus_tracking_screen.dart';
import 'owner_dashboard_screen.dart';
import 'passenger_search_screen.dart';
import 'routes_directory_screen.dart';

class HomeShellScreen extends StatelessWidget {
  const HomeShellScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NavigationCubit, NavigationState>(
      builder: (context, navState) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: _buildTopHeader(context, navState),
          body: _buildCurrentTabBody(navState.currentTab),
          bottomNavigationBar: _buildBottomNavigationBar(context, navState.currentTab),
        );
      },
    );
  }

  PreferredSizeWidget _buildTopHeader(BuildContext context, NavigationState navState) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(112),
      child: Container(
        color: AppColors.surface.withValues(alpha: 0.95),
        padding: const EdgeInsets.only(top: 8, left: 16, right: 16, bottom: 8),
        child: SafeArea(
          bottom: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Branding Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.directions_bus,
                          color: AppColors.onPrimary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'FindMyBus',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            'Kerala Bus Connect',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_none, size: 22),
                        color: AppColors.onSurfaceVariant,
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('No new transit alerts')),
                          );
                        },
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 4),
                      BlocBuilder<AuthBloc, AuthState>(
                        builder: (context, auth) {
                          final isLogged = auth.status == AuthStatus.authenticated;
                          return InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              if (isLogged) {
                                context.read<AuthBloc>().add(const AuthSignOutRequested());
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Signed out successfully')),
                                );
                              } else {
                                context.read<NavigationCubit>().setTab(AppTab.ownersPortal);
                              }
                            },
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor: isLogged ? AppColors.primary : AppColors.surfaceLow,
                              child: Icon(
                                isLogged ? Icons.logout : Icons.person,
                                size: 18,
                                color: isLogged ? AppColors.onPrimary : AppColors.primary,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Segmented Passengers vs Bus Owners Pill Switcher
              Container(
                height: 38,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => context.read<NavigationCubit>().togglePassengerOwner(false),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: !navState.isOwnerMode
                                ? AppColors.card
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: !navState.isOwnerMode
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.06),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Text(
                            'Passengers',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: !navState.isOwnerMode
                                  ? AppColors.primary
                                  : AppColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => context.read<NavigationCubit>().togglePassengerOwner(true),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: navState.isOwnerMode
                                ? AppColors.primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: navState.isOwnerMode
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.06),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Text(
                            'Bus Owners',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: navState.isOwnerMode
                                  ? AppColors.onPrimary
                                  : AppColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentTabBody(AppTab tab) {
    switch (tab) {
      case AppTab.timetables:
        return const PassengerSearchScreen();
      case AppTab.liveTrack:
        return const LiveBusTrackingScreen();
      case AppTab.routes:
        return const RoutesDirectoryScreen();
      case AppTab.dutyRoster:
        return const CrewDutyRosterScreen();
      case AppTab.ownersPortal:
        return const OwnerDashboardScreen();
    }
  }

  Widget _buildBottomNavigationBar(BuildContext context, AppTab currentTab) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.95),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(
                context,
                icon: Icons.schedule,
                label: 'Timetables',
                tab: AppTab.timetables,
                active: currentTab == AppTab.timetables,
              ),
              _navItem(
                context,
                icon: Icons.fmd_good,
                label: 'Live Track',
                tab: AppTab.liveTrack,
                active: currentTab == AppTab.liveTrack,
              ),
              _navItem(
                context,
                icon: Icons.alt_route,
                label: 'Routes',
                tab: AppTab.routes,
                active: currentTab == AppTab.routes,
              ),
              _navItem(
                context,
                icon: Icons.badge_outlined,
                label: 'Duty Roster',
                tab: AppTab.dutyRoster,
                active: currentTab == AppTab.dutyRoster,
              ),
              _navItem(
                context,
                icon: Icons.directions_bus,
                label: 'Owners',
                tab: AppTab.ownersPortal,
                active: currentTab == AppTab.ownersPortal,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required AppTab tab,
    required bool active,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.read<NavigationCubit>().setTab(tab),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: active ? AppColors.primary : AppColors.onSurfaceVariant,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? AppColors.primary : AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
