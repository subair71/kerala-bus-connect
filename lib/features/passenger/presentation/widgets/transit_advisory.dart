import 'package:flutter/material.dart';
import '../../../../core/theme/home_theme.dart';

class TransitAdvisory extends StatelessWidget {
  const TransitAdvisory({super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: HomeTheme.advisory,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CircleAvatar(
          radius: 17,
          backgroundColor: Colors.white,
          child: Icon(Icons.info_outline, size: 19, color: HomeTheme.primary),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Transit advisory',
                style: TextStyle(
                  fontSize: 16,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                  color: HomeTheme.text,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Timetable estimates are scheduled departures, not live GPS tracking. Traffic and route changes may affect actual arrival times. Confirm your journey with the operator before travel.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.7,
                  color: HomeTheme.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Future<void> showTransitAdvisory(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Close advisory',
                onPressed: () => Navigator.pop(sheetContext),
                icon: const Icon(Icons.close),
              ),
            ),
            const TransitAdvisory(),
          ],
        ),
      ),
    );
