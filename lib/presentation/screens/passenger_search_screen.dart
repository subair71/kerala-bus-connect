import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/transit_constants.dart';
import '../../core/di/injection.dart';
import '../../core/utils/time_utils.dart';
import '../../domain/entities/service_entity.dart';
import '../../domain/repositories/transit_repository.dart';
import '../blocs/passenger/search_cubit.dart';
import '../blocs/passenger/search_state.dart';
import '../widgets/train_route_view.dart';

class PassengerSearchScreen extends StatelessWidget {
  const PassengerSearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final transitRepo = sl<TransitRepository>();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero Banner from Stitch design
              _buildHeroBanner(),
              const SizedBox(height: 16),

              // Search Box Card with Floating Swap & Quick Chips
              _buildSearchCard(context),
              const SizedBox(height: 20),

              // Live Departures Section Streamed from Clean Repository
              StreamBuilder<List<ServiceEntity>>(
                stream: transitRepo.getPublishedServices(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(color: AppColors.primary),
                      ),
                    );
                  }

                  final allServices = snapshot.data ?? [];

                  return BlocBuilder<SearchCubit, SearchState>(
                    builder: (context, state) {
                      final filtered = _filterServices(allServices, state);
                      return _buildDeparturesList(context, filtered, state);
                    },
                  );
                },
              ),

              const SizedBox(height: 16),
              _buildQuickActions(context),
              const SizedBox(height: 16),
              _buildAdvisoryTip(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'KERALA TRANSIT TIMETABLE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: AppColors.secondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'KSRTC & Private',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Find Bus Timings',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.onSurface,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Accurate schedules, stop sequences, and live departure status.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchCard(BuildContext context) {
    return BlocBuilder<SearchCubit, SearchState>(
      builder: (context, state) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Origin & Destination Inputs with Floating Swap
              Stack(
                alignment: Alignment.centerRight,
                children: [
                  Column(
                    children: [
                      // Origin Input
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.radio_button_checked,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'From',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                  TextFormField(
                                    key: ValueKey('from_${state.from}'),
                                    initialValue: state.from,
                                    onChanged: (val) => context
                                        .read<SearchCubit>()
                                        .updateFrom(val),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.onSurface,
                                    ),
                                    decoration: const InputDecoration(
                                      hintText: 'Boarding stop (e.g. Aluva)',
                                      isDense: true,
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (state.from.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.close, size: 16),
                                onPressed: () =>
                                    context.read<SearchCubit>().updateFrom(''),
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Destination Input
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              color: AppColors.secondary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'To',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                  TextFormField(
                                    key: ValueKey('to_${state.to}'),
                                    initialValue: state.to,
                                    onChanged: (val) => context
                                        .read<SearchCubit>()
                                        .updateTo(val),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.onSurface,
                                    ),
                                    decoration: const InputDecoration(
                                      hintText: 'Destination stop (e.g. Kaloor)',
                                      isDense: true,
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (state.to.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.close, size: 16),
                                onPressed: () =>
                                    context.read<SearchCubit>().updateTo(''),
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Floating Swap Button positioned on the right
                  Positioned(
                    right: 14,
                    child: Material(
                      elevation: 2,
                      shape: const CircleBorder(),
                      color: AppColors.card,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () =>
                            context.read<SearchCubit>().swapFromAndTo(),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            Icons.swap_vert,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Quick Popular Destination Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const Text(
                      'Quick: ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 4),
                    for (final stop in popularKeralaStops.take(6))
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          label: Text(stop),
                          labelStyle: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: state.to.toLowerCase() == stop.toLowerCase()
                                ? AppColors.primary
                                : AppColors.onSurfaceVariant,
                          ),
                          backgroundColor:
                              state.to.toLowerCase() == stop.toLowerCase()
                                  ? AppColors.secondaryContainer
                                  : AppColors.surfaceLow,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide.none,
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 0),
                          onPressed: () => context
                              .read<SearchCubit>()
                              .selectPopularDestination(stop),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Day Filter & Active Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 15,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: state.filterDay,
                          isDense: true,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurface,
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: 'All Days',
                              child: Text('All Days (Overview)'),
                            ),
                            for (final d in weekDays)
                              DropdownMenuItem(
                                value: d,
                                child: Text(d == todayName() ? '$d (Today)' : d),
                              ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              context.read<SearchCubit>().setFilterDay(val);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Text(
                        'Running today only',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Switch.adaptive(
                        value: state.onlyRunningToday,
                        activeColor: AppColors.primary,
                        onChanged: (val) => context
                            .read<SearchCubit>()
                            .toggleOnlyRunningToday(val),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  List<ServiceEntity> _filterServices(
      List<ServiceEntity> allServices, SearchState state) {
    final fromTerm = state.from.trim().toLowerCase();
    final toTerm = state.to.trim().toLowerCase();
    final dayTerm =
        state.filterDay == 'All Days' ? todayName() : state.filterDay;

    return allServices.where((svc) {
      if (state.onlyRunningToday && svc.offDays.contains(todayName())) {
        return false;
      }
      if (state.filterDay != 'All Days' && svc.offDays.contains(dayTerm)) {
        return false;
      }

      final stopsLower = svc.stops.map((s) => s.toLowerCase()).toList();

      if (fromTerm.isNotEmpty && toTerm.isNotEmpty) {
        final iFrom = stopsLower.indexWhere((s) => s.contains(fromTerm));
        final iTo = stopsLower.indexWhere((s) => s.contains(toTerm));
        return iFrom != -1 && iTo != -1 && iFrom < iTo;
      } else if (fromTerm.isNotEmpty) {
        return stopsLower.any((s) => s.contains(fromTerm));
      } else if (toTerm.isNotEmpty) {
        return stopsLower.any((s) => s.contains(toTerm));
      }
      return true;
    }).toList()
      ..sort((a, b) => a.departureMinutes.compareTo(b.departureMinutes));
  }

  Widget _buildDeparturesList(
      BuildContext context, List<ServiceEntity> services, SearchState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section Header with Live Beacon
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text(
                  'Upcoming Departures',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${services.length} buses',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.secondary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Live status',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (services.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.directions_bus_outlined,
                  size: 44,
                  color: AppColors.outlineVariant,
                ),
                SizedBox(height: 12),
                Text(
                  'No buses found for this sequence',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Try searching connecting stops like Aluva, Kaloor, or Fort Kochi.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          )
        else
          for (final svc in services) _buildServiceCard(context, svc, state),
      ],
    );
  }

  Widget _buildServiceCard(
      BuildContext context, ServiceEntity svc, SearchState state) {
    final nowMins = minutesNow();
    final diff = svc.departureMinutes - nowMins;
    final minsDisplay = diff > 0 && diff < 120 ? 'in $diff min' : 'Scheduled';
    final boardingTime = timeLabel(svc.getBoardingTime(state.from));
    final isOffToday = svc.offDays.contains(todayName());

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Bus Title & Departure Time
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            svc.busName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLow,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            svc.routeName.contains('Fast')
                                ? 'Fast Passenger'
                                : 'Limited Stop',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${svc.routeName} • Private Transit',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    boardingTime,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    minsDisplay,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Route Pathway & Stop Tags
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      svc.stops.first,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        Icons.arrow_forward,
                        size: 14,
                        color: AppColors.outlineVariant,
                      ),
                    ),
                    Text(
                      svc.stops.length > 2
                          ? svc.stops[svc.stops.length ~/ 2]
                          : svc.stops.last,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        Icons.arrow_forward,
                        size: 14,
                        color: AppColors.outlineVariant,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        svc.stops.last,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const Text(
                '₹22',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),

          if (isOffToday)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Note: Not running on Sundays/Holidays',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.error,
                  ),
                ),
              ),
            ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 8),

          // Action Buttons: View Route Ladder (Train Route style) & Track
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${svc.stops.length} Stops sequence',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.alt_route, size: 16),
                label: const Text(
                  'Train Route Ladder',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (sheetContext) => FractionallySizedBox(
                      heightFactor: 0.85,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: AppColors.background,
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(24)),
                        ),
                        child: TrainRouteView(
                          service: svc,
                          queryFrom: state.from,
                          queryTo: state.to,
                          effectiveDay: state.filterDay == 'All Days'
                              ? todayName()
                              : state.filterDay,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.bookmark_border, size: 16),
            label: const Text('Save Route'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.onSurface,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Route saved to offline quick list')),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.swap_horiz, size: 16),
            label: const Text('Return Trips'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.onSurface,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => context.read<SearchCubit>().swapFromAndTo(),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.share, size: 16),
            label: const Text('Share'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.onSurface,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Timetable link copied to clipboard')),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAdvisoryTip() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(12),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 20, color: AppColors.outline),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Peak Hour Advisory',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Morning express departures operate at ~7 min intervals on the Aluva-Kaloor highway corridor. Exact change or Chalo/UPI card encouraged.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
