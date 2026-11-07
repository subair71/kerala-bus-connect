import 'dart:async';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Each mounted loading region owns a cancellable delay, never a data request.
final shimmerDelayProvider = NotifierProvider.autoDispose
    .family<ShimmerDelay, bool, Object>(ShimmerDelay.new);

class ShimmerDelay extends Notifier<bool> {
  ShimmerDelay(this.identity);
  final Object identity;

  @override
  bool build() {
    final timer = Timer(const Duration(milliseconds: 120), () {
      if (ref.mounted) state = true;
    });
    ref.onDispose(timer.cancel);
    return false;
  }
}
