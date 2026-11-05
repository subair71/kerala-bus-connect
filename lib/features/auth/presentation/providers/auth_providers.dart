import 'dart:async';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/providers/firebase_providers.dart';
import '../../data/repositories/firebase_auth_repository.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/authenticate.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => FirebaseAuthRepository(ref.watch(firebaseAuthProvider)),
);
final authenticateProvider = Provider<Authenticate>(
  (ref) => Authenticate(ref.watch(authRepositoryProvider)),
);
final authUserProvider = StreamProvider<AuthUser?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});
final ownerIdProvider = Provider<String?>(
  (ref) => ref.watch(authUserProvider).asData?.value?.id,
);

final authModeProvider = NotifierProvider.autoDispose<AuthMode, bool>(
  AuthMode.new,
);

class AuthMode extends Notifier<bool> {
  @override
  bool build() => false;
  void toggle() => state = !state;
}

final authActionProvider = AsyncNotifierProvider.autoDispose<AuthAction, void>(
  AuthAction.new,
);

class AuthAction extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> submit(
    String email,
    String password, {
    required bool register,
  }) async {
    if (state.isLoading) return;
    final authenticate = ref.read(authenticateProvider);
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => authenticate(email: email, password: password, register: register),
    );
    if (ref.mounted) state = result;
  }

  Future<void> signOut() async {
    if (state.isLoading) return;
    final repository = ref.read(authRepositoryProvider);
    state = const AsyncLoading();
    final result = await AsyncValue.guard(repository.signOut);
    if (ref.mounted) state = result;
  }
}
