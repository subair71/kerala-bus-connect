import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';

class LiveBusTrackingScreen extends StatelessWidget {
  const LiveBusTrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Tracking Context Floating Card
              _buildTopContextCard(context),
              const SizedBox(height: 14),

              // Interactive Map Canvas Container
              _buildMapCanvas(),
              const SizedBox(height: 14),

              // 3 Quick Metrics Cards
              _buildMetricsRow(),
              const SizedBox(height: 16),

              // Route Timeline
              _buildRouteTimeline(context),
              const SizedBox(height: 16),

              // Crew Profile & SOS
              _buildCrewAndEmergencyCard(context),
              const SizedBox(height: 14),

              // CTA Action Button
              _buildDestinationAlertButton(context),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopContextCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.secondaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.directions_bus,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Flexible(
                            child: Text(
                              'Joshy Mon',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'KL-07-CK-4219',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Aluva Stand ➔ Fort Kochi Jetty',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLow,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
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
                      '42 km/h • On Time',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.share, size: 18),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Live tracking link copied')),
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

  Widget _buildMapCanvas() {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: const Color(0xfff1f5f9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _KeralaMapPainter(),
            ),
          ),
          // Zoom & Recenter controls
          Positioned(
            right: 14,
            bottom: 14,
            child: Column(
              children: [
                Material(
                  elevation: 2,
                  shape: const CircleBorder(),
                  color: AppColors.card,
                  child: IconButton(
                    icon: const Icon(Icons.my_location,
                        size: 18, color: AppColors.primary),
                    onPressed: () {},
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(height: 8),
                Material(
                  elevation: 2,
                  borderRadius: BorderRadius.circular(20),
                  color: AppColors.card,
                  child: Column(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.add, size: 16),
                        onPressed: () {},
                        visualDensity: VisualDensity.compact,
                      ),
                      Container(
                        height: 1,
                        width: 20,
                        color: AppColors.border,
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove, size: 16),
                        onPressed: () {},
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Delay Alert Notice Pill
          Positioned(
            left: 14,
            bottom: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.card.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.info, size: 15, color: AppColors.tertiary),
                  SizedBox(width: 6),
                  Text(
                    '+2m delay near Edappally Toll Bypass',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsRow() {
    return Row(
      children: [
        Expanded(
          child: _metricCard('Next Stop', '4 min', '850m away', AppColors.primary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _metricCard('Occupancy', '40%', 'Seats Free', AppColors.secondary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _metricCard('Fare', '₹22', 'UPI / Card OK', AppColors.onSurface),
        ),
      ],
    );
  }

  Widget _metricCard(
      String title, String mainValue, String subValue, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            mainValue,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subValue,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteTimeline(BuildContext context) {
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
                'Route Timeline',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              Text(
                '6 stops total',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Passed Stop 1
          _buildTimelineStop(
            name: 'Aluva Private Stand',
            timeInfo: 'Departed 8:00 AM',
            isPassed: true,
            isCurrent: false,
          ),

          // Passed Stop 2
          _buildTimelineStop(
            name: 'Kalamassery Premier Jn',
            timeInfo: 'Departed 8:14 AM',
            isPassed: true,
            isCurrent: false,
          ),

          // Approaching Next Stop with Alarm
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Approaching Next',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const Text(
                      '8:26 AM (in 4 min)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Edappally Toll Bypass',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                const Text(
                  'Direct interchange to Kochi Metro Station',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Next stop ring',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.alarm, size: 14),
                      label: const Text('Set Alarm'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Alarm set for Edappally Toll!')),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Upcoming Stop
          _buildTimelineStop(
            name: 'Kaloor Stadium Jn',
            timeInfo: '5.2 km away • 8:38 AM',
            isPassed: false,
            isCurrent: false,
          ),

          // Final Stop
          _buildTimelineStop(
            name: 'Fort Kochi Boat Jetty',
            timeInfo: 'Final Terminal • 9:15 AM',
            isPassed: false,
            isCurrent: false,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineStop({
    required String name,
    required String timeInfo,
    required bool isPassed,
    required bool isCurrent,
    bool isLast = false,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vertical line & Indicator node
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isPassed
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : AppColors.surfaceLow,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPassed
                      ? Icons.check
                      : (isLast ? Icons.flag : Icons.schedule),
                  size: 13,
                  color: isPassed ? AppColors.primary : AppColors.outline,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isPassed
                        ? AppColors.primary.withValues(alpha: 0.3)
                        : AppColors.border,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              isPassed ? FontWeight.w600 : FontWeight.w500,
                          color: isPassed
                              ? AppColors.onSurface
                              : AppColors.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        timeInfo,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    isPassed ? 'Passed' : 'Upcoming',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isPassed
                          ? AppColors.onSurfaceVariant
                          : AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCrewAndEmergencyCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppColors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Text(
                  'JM',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Joshy Mon Express',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                  Text(
                    'Driver: Venu K. • Verified Crew',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.call, size: 14, color: AppColors.error),
            label: const Text(
              'SOS',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.error),
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Kerala MVD Transit helpline: 112')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDestinationAlertButton(BuildContext context) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.notifications_active, size: 18),
      label: const Text(
        'Set Destination Drop Alert (Fort Kochi)',
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Destination alert enabled for Fort Kochi!')),
        );
      },
    );
  }
}

class _KeralaMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Background fill
    final bgPaint = Paint()..color = const Color(0xfff0f4f8);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // River (Periyar River flow representation)
    final riverPaint = Paint()
      ..color = const Color(0xffdbeafe)
      ..strokeWidth = 24
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final riverPath = Path()
      ..moveTo(0, size.height * 0.25)
      ..quadraticBezierTo(size.width * 0.4, size.height * 0.15, size.width, size.height * 0.35);
    canvas.drawPath(riverPath, riverPaint);

    // Major Arterial Highway (NH 544 / Highway Route)
    final routePaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final routePath = Path()
      ..moveTo(size.width * 0.12, size.height * 0.18)
      ..cubicTo(
        size.width * 0.35,
        size.height * 0.35,
        size.width * 0.65,
        size.height * 0.65,
        size.width * 0.88,
        size.height * 0.85,
      );
    canvas.drawPath(routePath, routePaint);

    // Stations/Stops along the route
    final points = [
      Offset(size.width * 0.12, size.height * 0.18), // Aluva
      Offset(size.width * 0.32, size.height * 0.33), // Kalamassery
      Offset(size.width * 0.50, size.height * 0.50), // Edappally Toll
      Offset(size.width * 0.68, size.height * 0.67), // Kaloor
      Offset(size.width * 0.88, size.height * 0.85), // Fort Kochi
    ];

    final nodePaint = Paint()..color = Colors.white;
    final nodeBorder = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    for (final pt in points) {
      canvas.drawCircle(pt, 5, nodePaint);
      canvas.drawCircle(pt, 5, nodeBorder);
    }

    // Live Bus Node (approaching Edappally Toll)
    final busPos = Offset(size.width * 0.46, size.height * 0.46);

    // Pulse ring
    final pulsePaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(busPos, 14, pulsePaint);

    // Bus center
    final busPaint = Paint()..color = AppColors.primary;
    canvas.drawCircle(busPos, 7, busPaint);
    final busCore = Paint()..color = Colors.white;
    canvas.drawCircle(busPos, 3, busCore);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
