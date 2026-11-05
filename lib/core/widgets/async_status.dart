import 'package:flutter/material.dart';
import '../constants/colors.dart';
import 'app_components.dart';

class AsyncStatus extends StatelessWidget {
  final String message;
  final bool loading;
  final VoidCallback? retry;
  const AsyncStatus({
    super.key,
    this.message = '',
    this.loading = false,
    this.retry,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (loading)
          const SizedBox(width: 28, height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5))
        else ...[
          AppIconTile(retry == null ? Icons.search_off_outlined : Icons.wifi_off_rounded),
          const SizedBox(height: 14),
          Text(message, textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.onSurfaceVariant, height: 1.5)),
        ],
        if (retry != null) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: retry,
            icon: const Icon(Icons.refresh, size: 18), label: const Text('Retry')),
        ],
      ],
    ),
  );
}
