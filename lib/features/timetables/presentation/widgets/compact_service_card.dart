import 'package:flutter/material.dart';
import '../../../../core/theme/home_theme.dart';
import '../../../../core/utils/time_utils.dart';
import '../../domain/entities/service_entity.dart';

/// Compact schedule card matching the supplied passenger-home reference.
class CompactServiceCard extends StatelessWidget {
  final ServiceEntity service;
  final String boarding, destination, status;
  final int? departure, arrival, duration, demoFare;
  final String? demoFareLabel;
  final bool demo, running;
  final VoidCallback onViewStops;
  const CompactServiceCard({
    super.key, required this.service, required this.boarding,
    required this.destination, required this.status, required this.departure,
    required this.arrival, required this.duration, required this.demo,
    required this.running, required this.onViewStops,
    this.demoFare, this.demoFareLabel,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = !service.operatingDaysKnown
      ? HomeTheme.muted : running ? HomeTheme.primary : Theme.of(context).colorScheme.error;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(spacing: 8, runSpacing: 6, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: running && service.operatingDaysKnown
                        ? HomeTheme.positiveSurface : HomeTheme.field,
                      borderRadius: BorderRadius.circular(6)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(running ? Icons.circle : Icons.schedule,
                        size: running ? 6 : 12, color: statusColor),
                      const SizedBox(width: 5),
                      Flexible(child: Text(status,
                        style: TextStyle(fontSize: 11, height: 1.2, color: statusColor))),
                    ]),
                  ),
                  if (demo) Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: HomeTheme.field,
                      borderRadius: BorderRadius.circular(6)),
                    child: const Text('Demo', style: TextStyle(fontSize: 11, color: HomeTheme.muted))),
                ]),
              )),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(demo && demoFare != null ? '₹$demoFare' : '—',
                  style: const TextStyle(fontSize: 22, height: 1.2,
                    fontWeight: FontWeight.w700, letterSpacing: -.5, color: HomeTheme.primary)),
                Text(demo && demoFare != null ? demoFareLabel ?? 'Sample fare' : 'Fare unavailable',
                  style: const TextStyle(fontSize: 11, height: 1.4, color: HomeTheme.muted)),
              ]),
            ]),
          ),
          const SizedBox(height: 10),
          Text(service.busName, style: const TextStyle(fontSize: 17,
            height: 1.4, fontWeight: FontWeight.w700, letterSpacing: -.4, color: HomeTheme.text)),
          const SizedBox(height: 2),
          Text(service.routeName, style: const TextStyle(fontSize: 12,
            height: 1.5, color: HomeTheme.muted)),
          const SizedBox(height: 12),
          _Timings(boarding: boarding, destination: destination,
            departure: departure, arrival: arrival, duration: duration),
          const SizedBox(height: 4),
          LayoutBuilder(builder: (context, constraints) {
            final large = MediaQuery.textScalerOf(context).scale(14) > 19;
            final operator = Row(children: [
              const Icon(Icons.directions_bus_outlined, size: 14, color: HomeTheme.primary),
              const SizedBox(width: 6),
              Expanded(child: Text(service.businessName,
                maxLines: large ? 3 : 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, height: 1.4, color: HomeTheme.muted))),
            ]);
            final action = Tooltip(
              message: 'View stop timings',
              child: FilledButton.icon(
                key: ValueKey('stop-timings-${service.id}'),
                onPressed: onViewStops,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(48, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  shape: const StadiumBorder(),
                  backgroundColor: HomeTheme.primary,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontFamily: 'Plus Jakarta Sans',
                    fontSize: 13, fontWeight: FontWeight.w600),
                ),
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.arrow_forward, size: 17),
                label: const Text('View Stops'),
              ),
            );
            if (large) return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [const SizedBox(height: 8), operator, const SizedBox(height: 8), action]);
            return Row(children: [
              Expanded(child: operator), const SizedBox(width: 8), action]);
          }),
          if (!demo && (service.offTimingsNote?.isNotEmpty ?? false))
            Padding(padding: const EdgeInsets.only(bottom: 6),
              child: Text(service.offTimingsNote?.isNotEmpty == true
                ? service.offTimingsNote! : 'Sample data • not for travel planning.',
                style: const TextStyle(fontSize: 10, height: 1.4, color: HomeTheme.muted))),
        ]),
      ),
    );
  }
}

class _Timings extends StatelessWidget {
  final String boarding, destination;
  final int? departure, arrival, duration;
  const _Timings({required this.boarding, required this.destination,
    required this.departure, required this.arrival, required this.duration});

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 72),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(color: HomeTheme.timing,
      borderRadius: BorderRadius.circular(16)),
    child: LayoutBuilder(builder: (context, constraints) {
      final large = MediaQuery.textScalerOf(context).scale(14) > 19;
      Widget end(bool last) {
        final time = last ? arrival : departure;
        final stop = last ? destination : boarding;
        final right = last && !large;
        return Column(
          crossAxisAlignment: right ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(time == null ? 'Time unavailable' : timeLabel(time).padLeft(8, '0'),
              textAlign: right ? TextAlign.right : TextAlign.left,
              style: TextStyle(fontSize: time == null ? 12 : constraints.maxWidth < 260 ? 14 : 17,
                height: 1.4, fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
                letterSpacing: -.3, color: HomeTheme.text)),
            Text(stop.isEmpty ? 'Stop unavailable' : stop,
              maxLines: 2, overflow: TextOverflow.ellipsis,
              textAlign: right ? TextAlign.right : TextAlign.left,
              style: const TextStyle(fontSize: 11, height: 1.4, color: HomeTheme.muted)),
          ],
        );
      }
      final center = Column(children: [
        Text(duration == null ? '—' : '$duration mins',
          style: const TextStyle(fontSize: 11, height: 1.3, color: HomeTheme.muted)),
        SizedBox(height: 14, child: Stack(alignment: Alignment.center, children: [
          const Positioned(left: 2, right: 2, child: SizedBox(height: 1,
            child: ColoredBox(color: HomeTheme.primary))),
          const Align(alignment: Alignment.centerLeft,
            child: Icon(Icons.circle, size: 7, color: HomeTheme.primary)),
          const Align(alignment: Alignment.centerRight,
            child: Icon(Icons.circle, size: 7, color: HomeTheme.primary)),
          const ColoredBox(color: HomeTheme.timing,
            child: Icon(Icons.navigation_outlined, size: 13, color: HomeTheme.primary)),
        ])),
        const Text('Scheduled', style: TextStyle(fontSize: 11,
          height: 1.2, color: HomeTheme.primary)),
      ]);
      if (large) return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [end(false), const SizedBox(height: 12), end(true),
          const SizedBox(height: 12), center]);
      return Row(children: [
        Expanded(flex: 3, child: end(false)),
        Expanded(flex: 4, child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8), child: center)),
        Expanded(flex: 3, child: end(true)),
      ]);
    }),
  );
}
