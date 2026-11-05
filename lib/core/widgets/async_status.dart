import 'package:flutter/material.dart';

class AsyncStatus extends StatelessWidget {
  final String message;
  final bool loading;
  final VoidCallback? retry;
  const AsyncStatus({super.key, this.message = '', this.loading = false, this.retry});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      if (loading) const CircularProgressIndicator()
      else Text(message, textAlign: TextAlign.center),
      if (retry != null) TextButton(onPressed: retry, child: const Text('Retry')),
    ]),
  );
}
