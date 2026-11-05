import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/errors/app_failure.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _auth;
  const FirebaseAuthRepository(this._auth);

  AuthUser? _map(User? user) => user == null || user.isAnonymous
      ? null
      : AuthUser(id: user.uid, email: user.email);

  @override
  AuthUser? get currentUser => _map(_auth.currentUser);
  @override
  Stream<AuthUser?> get authStateChanges =>
      _auth.authStateChanges().map(_map).distinct();

  Future<void> _perform(Future<void> Function() action) async {
    try {
      await action();
    } on FirebaseAuthException catch (error) {
      throw AppFailure(switch (error.code) {
        'invalid-credential' ||
        'wrong-password' ||
        'user-not-found' => 'Email or password is incorrect.',
        'email-already-in-use' =>
          'This email already has an account. Please sign in.',
        'network-request-failed' =>
          'Unable to connect. Check your internet connection.',
        'too-many-requests' => 'Too many attempts. Please try again later.',
        'weak-password' => 'Please choose a stronger password.',
        _ => error.message ?? 'Authentication failed. Please try again.',
      });
    }
  }

  @override
  Future<void> signIn(String email, String password) => _perform(() async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  });
  @override
  Future<void> register(String email, String password) => _perform(() async {
    await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  });
  @override
  Future<void> signOut() => _perform(_auth.signOut);
}
