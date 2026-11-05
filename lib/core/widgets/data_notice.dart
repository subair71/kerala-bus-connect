import 'package:flutter/material.dart';
import '../constants/colors.dart';

class DataNotice extends StatelessWidget {
  final bool demo, unavailable;
  final VoidCallback? retry;
  const DataNotice({super.key, required this.demo, this.unavailable = false, this.retry});
  @override
  Widget build(BuildContext context) {
    if (!demo && !unavailable) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: AppColors.surfaceLow, borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        const Icon(Icons.info_outline, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(child: Text(unavailable
          ? 'Live data unavailable • Sample data'
          : 'Sample data • Demo only', style: const TextStyle(fontSize: 12))),
        if (unavailable && retry != null)
          TextButton(onPressed: retry, child: const Text('Retry')),
      ]),
    );
  }
}

class DemoBadge extends StatelessWidget {
  const DemoBadge({super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(4)),
    child: const Text('Demo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
  );
}
