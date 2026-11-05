import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/di/injection.dart';
import 'core/theme/app_theme.dart';
import 'presentation/blocs/auth/auth_bloc.dart';
import 'presentation/blocs/auth/auth_event.dart';
import 'presentation/blocs/navigation/navigation_cubit.dart';
import 'presentation/blocs/owner/owner_bloc.dart';
import 'presentation/blocs/passenger/search_cubit.dart';
import 'presentation/screens/home_shell_screen.dart';

const firebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyB7h2kuVM8CvhNlkptsPtyKXXHUO4T1RQk',
  appId: '1:442982526142:web:6daaf45238e0cf8de442ef',
  messagingSenderId: '442982526142',
  projectId: 'findmybus-535ae',
  authDomain: 'findmybus-535ae.firebaseapp.com',
  storageBucket: 'findmybus-535ae.firebasestorage.app',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: firebaseOptions);
  await initDI();

  // Ensure Firestore rules allow reads by unauthenticated users or anonymous session
  if (FirebaseAuth.instance.currentUser == null) {
    try {
      await FirebaseAuth.instance.signInAnonymously();
    } catch (_) {
      // Data layer handles offline/fallback mode seamlessly
    }
  }

  runApp(const KeralaBusConnectApp());
}

class KeralaBusConnectApp extends StatelessWidget {
  const KeralaBusConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (_) => sl<AuthBloc>()..add(const AuthCheckRequested()),
        ),
        BlocProvider<NavigationCubit>(
          create: (_) => sl<NavigationCubit>(),
        ),
        BlocProvider<SearchCubit>(
          create: (_) => sl<SearchCubit>(),
        ),
        BlocProvider<OwnerBloc>(
          create: (_) => sl<OwnerBloc>(),
        ),
      ],
      child: MaterialApp(
        title: 'FindMyBus - Kerala Bus Connect',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const HomeShellScreen(),
      ),
    );
  }
}
