import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../core/config/firebase_config.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/async_status.dart';
import 'app_shell.dart';

final initializationProvider = FutureProvider<void>((ref) async {
  // Initialize before accessing Firebase APIs. Pre-SDK apps reads throw on Safari.
  // FlutterFire safely reuses the default app when these options already match.
  await Firebase.initializeApp(options: firebaseOptions);
});

class FindMyBusApp extends ConsumerWidget {
  const FindMyBusApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
    title: 'FindMyBus - Kerala Bus Connect',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.lightTheme,
    home: ref
        .watch(initializationProvider)
        .when(
          loading: () =>
              const Scaffold(body: Center(child: AsyncStatus(loading: true))),
          error: (_, stack) => Scaffold(
            body: Center(
              child: AsyncStatus(
                message:
                    'Unable to start FindMyBus. Please check your connection.',
                retry: () => ref.invalidate(initializationProvider),
              ),
            ),
          ),
          data: (_) => const AppShell(),
        ),
  );
}
