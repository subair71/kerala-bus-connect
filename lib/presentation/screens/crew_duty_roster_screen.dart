import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';

class CrewDutyRosterScreen extends StatelessWidget {
  const CrewDutyRosterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final searchController = TextEditingController();
    final ValueNotifier<String> filterShift = ValueNotifier<String>('All');

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              _buildHeader(),
              const SizedBox(height: 14),

              // Search & Shift Filter Bar
              _buildFilterBar(searchController, filterShift),
              const SizedBox(height: 16),

              // Active Vehicle Assignments Section
              _buildVehicleAssignmentsSection(context),
              const SizedBox(height: 18),

              // Standby Relievers Pool Section
              _buildStandbyRelievers(context),
              const SizedBox(height: 18),

              // Daily Bata Settlement Card
              _buildBataDisbursement(context),
              const SizedBox(height: 16),

              // WhatsApp / SMS Broadcast Button
              _buildBroadcastButton(context),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'STAFF MANAGEMENT',
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
                  color: AppColors.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Live Roster',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Crew Duty Roster',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.onSurface,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Aluva & Ernakulam Regional RTO Compliant Shifts & Driver Pairings.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(
      TextEditingController controller, ValueNotifier<String> filterShift) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: TextField(
            controller: controller,
            decoration: const InputDecoration(
              icon: Icon(Icons.search, color: AppColors.outline),
              hintText: 'Search crew by name, license, or bus number...',
              hintStyle:
                  TextStyle(fontSize: 13, color: AppColors.outlineVariant),
              border: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 10),
        ValueListenableBuilder<String>(
          valueListenable: filterShift,
          builder: (context, current, _) {
            final shifts = ['All (10)', 'Morning (4)', 'Evening (4)', 'Standby (2)'];
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final s in shifts)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(s),
                        selected: current == s.split(' ')[0],
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: current == s.split(' ')[0]
                              ? Colors.white
                              : AppColors.onSurfaceVariant,
                        ),
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.surfaceLow,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide.none,
                        ),
                        onSelected: (_) =>
                            filterShift.value = s.split(' ')[0],
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildVehicleAssignmentsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Vehicle Assignments',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
            Text(
              '3 active on road',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Assignment 1
        _buildAssignmentCard(
          context,
          busReg: 'KL-07-CK-4219',
          busName: 'Joshy Mon Express',
          route: 'Aluva ➔ Fort Kochi • Shift 1 (06:00 - 14:30)',
          badgeText: 'Trip 6/10',
          badgeColor: AppColors.secondary,
          driverName: 'Venu K.',
          driverBata: 'Bata: ₹900 (Settled)',
          conductorName: 'Shaji P.',
          conductorBata: 'Bata: ₹750 (Settled)',
        ),

        // Assignment 2
        _buildAssignmentCard(
          context,
          busReg: 'KL-07-BE-1984',
          busName: 'St. George',
          route: 'Aluva ➔ Angamaly • Departs 08:50 AM',
          badgeText: 'Ready',
          badgeColor: AppColors.primary,
          driverName: 'Biju M.',
          driverBata: 'Checked in • Heavy License',
          conductorName: 'Renjith K.',
          conductorBata: 'ETM Synced • Cash Bag Issued',
        ),

        // Assignment 3
        _buildAssignmentCard(
          context,
          busReg: 'KL-07-DM-7733',
          busName: 'Minnal Feeder',
          route: 'Split Shift • Handover @ Vytilla (14:00)',
          badgeText: 'Split Duty',
          badgeColor: AppColors.tertiary,
          driverName: 'Sanoop V.',
          driverBata: 'Shift A (until 14:00)',
          conductorName: 'Vipin Das',
          conductorBata: 'Full Day Shift',
        ),
      ],
    );
  }

  Widget _buildAssignmentCard(
    BuildContext context, {
    required String busReg,
    required String busName,
    required String route,
    required String badgeText,
    required Color badgeColor,
    required String driverName,
    required String driverBata,
    required String conductorName,
    required String conductorBata,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
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
                        busReg,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '• $busName',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    route,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.outline,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 10),

          // Driver Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.primaryContainer,
                    child: Icon(Icons.person, size: 18, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            driverName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurface,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            '(Driver)',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.outline,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        driverBata,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.outline,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.call, size: 18, color: AppColors.primary),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Calling Driver $driverName...')),
                  );
                },
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Conductor Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.secondary,
                    child:
                        Icon(Icons.confirmation_number, size: 16, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            conductorName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurface,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            '(Conductor)',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.outline,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        conductorBata,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.outline,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.call, size: 18, color: AppColors.primary),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Calling Conductor $conductorName...')),
                  );
                },
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStandbyRelievers(BuildContext context) {
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
                'Standby Relievers',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              Text(
                '2 available in depot',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Reliever 1
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.surfaceLow,
                    child: Icon(Icons.person_pin, size: 18, color: AppColors.primary),
                  ),
                  SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Manoj Kumar',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                      ),
                      Text(
                        'Driver • Heavy Passenger Vehicle License',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.outline,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surfaceLow,
                  foregroundColor: AppColors.onSurface,
                  visualDensity: VisualDensity.compact,
                  elevation: 0,
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Manoj Kumar deployed to standby route')),
                  );
                },
                child: const Text('Deploy'),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Reliever 2
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.surfaceLow,
                    child: Icon(Icons.person_pin, size: 18, color: AppColors.secondary),
                  ),
                  SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pradeep N.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                      ),
                      Text(
                        'Conductor • Digital ETM Machine Certified',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.outline,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surfaceLow,
                  foregroundColor: AppColors.onSurface,
                  visualDensity: VisualDensity.compact,
                  elevation: 0,
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Pradeep N. deployed as standby conductor')),
                  );
                },
                child: const Text('Deploy'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBataDisbursement(BuildContext context) {
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
                'Daily Bata Settlement',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              Text(
                '₹3,300 Pending Today',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.tertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Driver Rate (Full Shift)',
                style: TextStyle(fontSize: 12, color: AppColors.outline),
              ),
              Text(
                '₹900 / shift',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Conductor Rate (Full Day)',
                style: TextStyle(fontSize: 12, color: AppColors.outline),
              ),
              Text(
                '₹750 / day',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.account_balance_wallet, size: 16),
                  label: const Text('Disburse via UPI'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('UPI Bata disbursement batch initiated')),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.picture_as_pdf, size: 16),
                label: const Text('Muster Roll'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.onSurface,
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Generating RTO Form 14 Muster PDF...')),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBroadcastButton(BuildContext context) {
    return Column(
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.mark_chat_unread, size: 18),
          label: const Text(
            'Broadcast Shift Alert (WhatsApp & SMS)',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.surfaceContainerHigh,
            foregroundColor: AppColors.onSurface,
            padding: const EdgeInsets.symmetric(vertical: 14),
            minimumSize: const Size.fromHeight(48),
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Shift broadcast dispatched to crew via WhatsApp')),
            );
          },
        ),
        const SizedBox(height: 6),
        const Text(
          'MVD Kerala Roster Rule compliant • Syncs with Ernakulam Regional RTO',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
