import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/transit_constants.dart';
import '../../core/di/injection.dart';
import '../../core/utils/time_utils.dart';
import '../../domain/entities/business_entity.dart';
import '../../domain/entities/route_entity.dart';
import '../../domain/entities/service_entity.dart';
import '../../domain/repositories/transit_repository.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_event.dart';
import '../blocs/auth/auth_state.dart';
import '../blocs/owner/owner_bloc.dart';
import '../blocs/owner/owner_event.dart';
import '../blocs/owner/owner_state.dart';

class OwnerDashboardScreen extends StatelessWidget {
  const OwnerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        if (authState.status == AuthStatus.unauthenticated ||
            authState.user == null) {
          return _buildAuthRequiredView(context);
        }

        final ownerId = authState.user!.uid;
        return _buildOwnerDashboardView(context, ownerId);
      },
    );
  }

  Widget _buildAuthRequiredView(BuildContext context) {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final ValueNotifier<bool> isRegister = ValueNotifier<bool>(false);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings,
                    color: AppColors.primary,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                ValueListenableBuilder<bool>(
                  valueListenable: isRegister,
                  builder: (context, reg, _) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reg ? 'Create Owner Account' : 'Bus Owner Portal',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          reg
                              ? 'Register your private bus fleet with Kerala Bus Connect.'
                              : 'Sign in to manage fleets, configure stop timings, and publish conflict-free schedules.',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Operator Email',
                    hintText: 'owner@keralatransit.com',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 20),
                ValueListenableBuilder<bool>(
                  valueListenable: isRegister,
                  builder: (context, reg, _) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            final email = emailController.text.trim();
                            final pass = passwordController.text;
                            if (email.isEmpty || pass.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Enter email and password')),
                              );
                              return;
                            }
                            if (reg) {
                              context.read<AuthBloc>().add(
                                  AuthRegisterRequested(email, pass));
                            } else {
                              context
                                  .read<AuthBloc>()
                                  .add(AuthSignInRequested(email, pass));
                            }
                          },
                          child: Text(
                            reg ? 'Create Account' : 'Sign In as Owner',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => isRegister.value = !reg,
                          child: Text(
                            reg
                                ? 'Already have an account? Sign In'
                                : 'New operator? Register account',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOwnerDashboardView(BuildContext context, String ownerId) {
    final transitRepo = sl<TransitRepository>();

    return BlocListener<OwnerBloc, OwnerState>(
      listener: (context, state) {
        if (state.userMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.userMessage!),
              backgroundColor: state.isError
                  ? Colors.red.shade700
                  : AppColors.primaryContainer,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Fleet Identity Hero
                _buildFleetIdentityHero(context),
                const SizedBox(height: 14),

                // Today's Fleet Overview (Revenue, Punctuality, Digital vs Cash)
                _buildFleetOverviewCard(),
                const SizedBox(height: 14),

                // Quick Action Chips
                _buildQuickActionChips(context),
                const SizedBox(height: 16),

                // Managed Buses List from Stitch
                _buildManagedBusesList(context),
                const SizedBox(height: 18),

                // Route & Service Management Section
                _buildManagementSection(context, ownerId, transitRepo),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFleetIdentityHero(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.directions_bus,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Joshy Mon Fleet',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.secondary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    '3 of 4 active • Ernakulam Zone',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Dispatch'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Quick bus dispatch requested')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFleetOverviewCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Today\'s Fleet Overview',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              Row(
                children: [
                  CircleAvatar(radius: 3, backgroundColor: AppColors.secondary),
                  SizedBox(width: 4),
                  Text(
                    'Live Sync',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '₹18,450',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onSurface,
                    ),
                  ),
                  SizedBox(width: 6),
                  Text(
                    '/ ₹22,000 target',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              Text(
                '+12% vs yesterday',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Two tone progress bar (Digital 61%, Cash 39%)
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Row(
              children: [
                Expanded(
                  flex: 61,
                  child: Container(height: 6, color: AppColors.primary),
                ),
                Expanded(
                  flex: 39,
                  child: Container(
                      height: 6,
                      color: AppColors.secondary.withValues(alpha: 0.6)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Digital: ₹11,250 (UPI / Smartcard)',
                style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
              ),
              Text(
                'Cash: ₹7,200',
                style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 10),

          // Trips & Punctuality
          const Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trips Completed',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.onSurfaceVariant),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '28 / 42 Trips',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Punctuality',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.onSurfaceVariant),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '94% (3m avg)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionChips(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _quickChip(context, Icons.campaign, 'Notice Board', () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Notice broadcast sent')),
            );
          }),
          _quickChip(context, Icons.receipt_long, 'Toll & Tax Pass', () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('FASTag FAST pass active')),
            );
          }),
          _quickChip(context, Icons.calendar_month, 'Duty Roster', () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Switch to Crew Roster tab below')),
            );
          }),
        ],
      ),
    );
  }

  Widget _quickChip(BuildContext context, IconData icon, String label,
      VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        avatar: Icon(icon, size: 16, color: AppColors.primary),
        label: Text(label),
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.onSurface,
        ),
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.border),
        ),
        onPressed: onTap,
      ),
    );
  }

  Widget _buildManagedBusesList(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Managed Buses (4)',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
            Text(
              'Live Fleet',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Bus 1
        _busCard(
          name: 'Joshy Mon',
          reg: 'KL-07-CK-4219',
          route: 'Aluva Stand ➔ Fort Kochi Jetty',
          status: '42 km/h',
          statusColor: AppColors.secondary,
          driver: 'Driver: Venu K. • Occupancy 80%',
        ),

        // Bus 2
        _busCard(
          name: 'St. George',
          reg: 'KL-07-BE-1984',
          route: 'Aluva Stand ➔ Angamaly Stand',
          status: 'Idle Bay 3',
          statusColor: AppColors.tertiary,
          driver: 'Departs in 18m • Driver: Biju M.',
        ),

        // Bus 3
        _busCard(
          name: 'Minnal City',
          reg: 'KL-07-DM-7733',
          route: 'InfoPark ➔ Vytilla Hub Circular',
          status: '35 km/h',
          statusColor: AppColors.secondary,
          driver: 'Driver: Sanoop • 95% Full',
        ),
      ],
    );
  }

  Widget _busCard({
    required String name,
    required String reg,
    required String route,
    required String status,
    required Color statusColor,
    required String driver,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        reg,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    route,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.outline,
                    ),
                  ),
                ],
              ),
              Text(
                status,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                driver,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const Row(
                children: [
                  Icon(Icons.near_me, size: 14, color: AppColors.primary),
                  SizedBox(width: 4),
                  Text(
                    'Track',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildManagementSection(BuildContext context, String ownerId,
      TransitRepository transitRepo) {
    final businessNameCtrl = TextEditingController();
    final routeNameCtrl = TextEditingController();
    final fromCtrl = TextEditingController();
    final toCtrl = TextEditingController();
    final stopsCtrl = TextEditingController();
    final busNameCtrl = TextEditingController(text: 'KL-07-CK-4219');
    final noteCtrl = TextEditingController();
    final ValueNotifier<bool> createReturnToo = ValueNotifier<bool>(true);

    return StreamBuilder<List<BusinessEntity>>(
      stream: transitRepo.getOwnerBusinesses(ownerId),
      builder: (context, bSnap) {
        final businesses = bSnap.data ?? [];

        return BlocBuilder<OwnerBloc, OwnerState>(
          builder: (context, ownerState) {
            final activeBusiness = businesses.isNotEmpty
                ? (businesses.firstWhere(
                    (b) => b.id == ownerState.selectedBusinessId,
                    orElse: () => businesses.first,
                  ))
                : null;

            return Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Route & Timetable Configuration',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Manage your permits, create return routes, and customize per-stop timetable schedules without conflict.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Business Selector & Creator
                  if (businesses.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLow,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Create Your First Operator Business',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: businessNameCtrl,
                            decoration: const InputDecoration(
                              hintText: 'e.g. Joshy Mon Travels',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.onPrimary,
                            ),
                            onPressed: () {
                              context.read<OwnerBloc>().add(
                                    OwnerCreateBusiness(
                                      ownerId: ownerId,
                                      name: businessNameCtrl.text,
                                    ),
                                  );
                            },
                            child: const Text('Create Business'),
                          ),
                        ],
                      ),
                    )
                  else
                    Row(
                      children: [
                        const Text(
                          'Business: ',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurface,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: activeBusiness?.id,
                              isDense: true,
                              items: [
                                for (final b in businesses)
                                  DropdownMenuItem(
                                    value: b.id,
                                    child: Text(
                                      b.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  context.read<OwnerBloc>().add(
                                        OwnerSelectBusiness(val),
                                      );
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),

                  if (activeBusiness != null) ...[
                    // Routes Manager
                    _buildRouteCreatorAndList(
                      context,
                      ownerId: ownerId,
                      businessId: activeBusiness.id,
                      businessName: activeBusiness.name,
                      transitRepo: transitRepo,
                      ownerState: ownerState,
                      routeNameCtrl: routeNameCtrl,
                      fromCtrl: fromCtrl,
                      toCtrl: toCtrl,
                      stopsCtrl: stopsCtrl,
                      createReturnToo: createReturnToo,
                    ),
                    const SizedBox(height: 20),

                    // Timetable Publisher with Conflict Checker & Per-Stop Timings
                    if (ownerState.selectedRouteId != null)
                      _buildTimetablePublisher(
                        context,
                        ownerId: ownerId,
                        businessId: activeBusiness.id,
                        businessName: activeBusiness.name,
                        routeId: ownerState.selectedRouteId!,
                        transitRepo: transitRepo,
                        ownerState: ownerState,
                        busNameCtrl: busNameCtrl,
                        noteCtrl: noteCtrl,
                      ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRouteCreatorAndList(
    BuildContext context, {
    required String ownerId,
    required String businessId,
    required String businessName,
    required TransitRepository transitRepo,
    required OwnerState ownerState,
    required TextEditingController routeNameCtrl,
    required TextEditingController fromCtrl,
    required TextEditingController toCtrl,
    required TextEditingController stopsCtrl,
    required ValueNotifier<bool> createReturnToo,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '1. Routes & Halts',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 8),

        // Route Form Container
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                ownerState.isEditingRoute ? 'Edit Route' : 'Add New Route',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: routeNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Route Name (e.g. Aluva - Kaloor Express)',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: fromCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Origin Stand',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: toCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Destination Stand',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: stopsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Intermediate Stops (comma-separated)',
                  hintText: 'Companypady, Kalamassery, Edappally Toll',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<bool>(
                valueListenable: createReturnToo,
                builder: (context, returnVal, _) {
                  return CheckboxListTile(
                    value: returnVal,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Auto-generate return / reverse route too',
                      style: TextStyle(fontSize: 12),
                    ),
                    onChanged: (v) => createReturnToo.value = v ?? true,
                  );
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (ownerState.isEditingRoute)
                    TextButton(
                      onPressed: () {
                        context
                            .read<OwnerBloc>()
                            .add(OwnerCancelEditRoute());
                        routeNameCtrl.clear();
                        fromCtrl.clear();
                        toCtrl.clear();
                        stopsCtrl.clear();
                      },
                      child: const Text('Cancel'),
                    ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                    ),
                    onPressed: () {
                      final name = routeNameCtrl.text.trim();
                      final start = fromCtrl.text.trim();
                      final end = toCtrl.text.trim();
                      final intermediate = stopsCtrl.text.trim();

                      if (name.isEmpty || start.isEmpty || end.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Provide route name, origin, and destination')),
                        );
                        return;
                      }

                      context.read<OwnerBloc>().add(
                            OwnerSaveRoute(
                              ownerId: ownerId,
                              businessId: businessId,
                              businessName: businessName,
                              name: name,
                              startStop: start,
                              endStop: end,
                              intermediateStopsText: intermediate,
                              generateReturnRoute: createReturnToo.value,
                            ),
                          );

                      routeNameCtrl.clear();
                      fromCtrl.clear();
                      toCtrl.clear();
                      stopsCtrl.clear();
                    },
                    child: Text(ownerState.isEditingRoute
                        ? 'Update Route'
                        : 'Save Route'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // List of Business Routes
        StreamBuilder<List<RouteEntity>>(
          stream: transitRepo.getBusinessRoutes(businessId),
          builder: (context, snap) {
            final routes = snap.data ?? [];
            if (routes.isEmpty) {
              return const Text(
                'No routes added yet. Add your first route above.',
                style: TextStyle(
                    fontSize: 12, color: AppColors.onSurfaceVariant),
              );
            }

            return Column(
              children: [
                for (final r in routes)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: ownerState.selectedRouteId == r.id
                          ? AppColors.secondaryContainer.withValues(alpha: 0.5)
                          : AppColors.surfaceLow,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: ownerState.selectedRouteId == r.id
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                    ),
                    child: ListTile(
                      dense: true,
                      title: Text(
                        r.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text('${r.stops.length} stops: ${r.startStop} ➔ ${r.endStop}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.swap_horiz, size: 18),
                            tooltip: 'Generate Return Route',
                            onPressed: () {
                              context.read<OwnerBloc>().add(
                                    OwnerGenerateReturnRoute(
                                      ownerId: ownerId,
                                      businessId: businessId,
                                      businessName: businessName,
                                      originRouteId: r.id,
                                      originalStops: r.stops,
                                    ),
                                  );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 16),
                            onPressed: () {
                              routeNameCtrl.text = r.name;
                              fromCtrl.text = r.startStop;
                              toCtrl.text = r.endStop;
                              final inter = r.stops
                                  .where((s) =>
                                      s != r.startStop && s != r.endStop)
                                  .join(', ');
                              stopsCtrl.text = inter;
                              context
                                  .read<OwnerBloc>()
                                  .add(OwnerStartEditRoute(
                                    routeId: r.id,
                                    name: r.name,
                                    startStop: r.startStop,
                                    endStop: r.endStop,
                                    stopsText: inter,
                                  ));
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                size: 16, color: Colors.red),
                            onPressed: () {
                              context
                                  .read<OwnerBloc>()
                                  .add(OwnerDeleteRoute(r.id));
                            },
                          ),
                        ],
                      ),
                      onTap: () {
                        context.read<OwnerBloc>().add(OwnerSelectRoute(
                              r.id,
                              r.stops,
                            ));
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildTimetablePublisher(
    BuildContext context, {
    required String ownerId,
    required String businessId,
    required String businessName,
    required String routeId,
    required TransitRepository transitRepo,
    required OwnerState ownerState,
    required TextEditingController busNameCtrl,
    required TextEditingController noteCtrl,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 24, color: AppColors.border),
        const Text(
          '2. Timetable Publishing & Stop Timings',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 8),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: busNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Bus Name / Plate (e.g. KL-07-CK-4219 Joshy Mon)',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),

              // Departure Time Picker
              Row(
                children: [
                  const Text('Departure Time: '),
                  ActionChip(
                    label: Text(
                      timeLabel(ownerState.departure.hour * 60 +
                          ownerState.departure.minute),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: ownerState.departure,
                      );
                      if (picked != null) {
                        context
                            .read<OwnerBloc>()
                            .add(OwnerChangeDepartureTime(picked, const []));
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Toggle Per-Stop Timings
              CheckboxListTile(
                value: ownerState.customizeStopTimings,
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Customize each intermediate stop timing',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                onChanged: (v) {
                  context
                      .read<OwnerBloc>()
                      .add(OwnerToggleCustomizeStopTimings(v ?? false));
                },
              ),

              if (ownerState.customizeStopTimings &&
                  ownerState.stopTimeValues.isNotEmpty) ...[
                const SizedBox(height: 4),
                for (final entry in ownerState.stopTimeValues.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(entry.key,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                        ActionChip(
                          visualDensity: VisualDensity.compact,
                          label: Text(
                            timeLabel(entry.value.hour * 60 +
                                entry.value.minute),
                            style: const TextStyle(fontSize: 11),
                          ),
                          onPressed: () async {
                            final p = await showTimePicker(
                              context: context,
                              initialTime: entry.value,
                            );
                            if (p != null) {
                              context.read<OwnerBloc>().add(
                                    OwnerChangeStopTiming(entry.key, p),
                                  );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 10),

              // Not Service Days
              const Text(
                'Not Running Days (Off-Days):',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final d in weekDays)
                    FilterChip(
                      label: Text(d),
                      selected: ownerState.selectedOffDays.contains(d),
                      onSelected: (_) =>
                          context.read<OwnerBloc>().add(OwnerToggleOffDay(d)),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Off-Timings / Bypass Route Note (Optional)',
                  hintText: 'e.g. Runs via bypass on holidays',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              // Publish Service Button
              StreamBuilder<List<ServiceEntity>>(
                stream: transitRepo.getOwnerServices(ownerId),
                builder: (context, sSnap) {
                  final existing = sSnap.data ?? [];

                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      final bName = busNameCtrl.text.trim();
                      if (bName.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Enter a bus name')),
                        );
                        return;
                      }

                      // Conflict verification: Same exact bus cannot depart twice within 30 min
                      final currentMins = ownerState.departure.hour * 60 +
                          ownerState.departure.minute;
                      final conflict = existing.any((s) =>
                          s.busName.toLowerCase() == bName.toLowerCase() &&
                          (s.departureMinutes - currentMins).abs() < 30);

                      if (conflict) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Conflict Warning: Bus $bName already has a scheduled trip within 30 minutes! Adjust time or select another vehicle.'),
                            backgroundColor: Colors.red.shade700,
                          ),
                        );
                        return;
                      }

                      context.read<OwnerBloc>().add(
                            OwnerPublishService(
                              ownerId: ownerId,
                              businessId: businessId,
                              routeId: routeId,
                              businessName: businessName,
                              routeName: 'Aluva - Kaloor Transit',
                              busName: bName,
                              routeStops: const [
                                'Aluva',
                                'Kalamassery',
                                'Edappally Toll',
                                'Kaloor'
                              ],
                              offTimingsNote: noteCtrl.text.trim(),
                            ),
                          );
                    },
                    child: const Text('Publish Timetable to Commuters'),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
