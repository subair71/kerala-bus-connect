import 'dart:async';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final liveDataCacheDurationProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 30),
);

/// Reuses a query during brief tab switches, then releases its resources.
void retainWhileIdle(Ref ref, Duration duration) {
  final link = ref.keepAlive();
  Timer? expiry;
  ref.onCancel(() {
    expiry?.cancel();
    expiry = Timer(duration, link.close);
  });
  ref.onResume(() => expiry?.cancel());
  ref.onDispose(() => expiry?.cancel());
}
