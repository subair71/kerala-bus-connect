import 'package:flutter/material.dart';
import '../constants/colors.dart';
import 'app_components.dart';

class DataNotice extends StatelessWidget {
  final bool demo, unavailable, cached;
  final VoidCallback? retry;
  const DataNotice({
    super.key,
    required this.demo,
    this.unavailable = false,
    this.cached = false,
    this.retry,
  });
  @override
  Widget build(BuildContext context) {
    if (!demo && !unavailable && !cached) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.sampleSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.onSampleSurface.withValues(alpha: .12),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline,
            size: 18,
            color: AppColors.onSampleSurface,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              cached
                  ? 'Saved timetable • May be outdated. Reconnect to refresh.'
                  : unavailable
                  ? 'Live data unavailable • Sample data'
                  : 'Sample data • Demo only',
              style: const TextStyle(
                fontSize: 12,
                height: 1.5,
                color: AppColors.onSampleSurface,
              ),
            ),
          ),
          if (unavailable && retry != null)
            TextButton(onPressed: retry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class DemoBadge extends StatelessWidget {
  const DemoBadge({super.key});
  @override
  Widget build(BuildContext context) => const AppStatusBadge(
    label: 'Demo',
    foreground: AppColors.onSampleSurface,
    background: AppColors.sampleSurface,
    fontSize: 11,
  );
}
