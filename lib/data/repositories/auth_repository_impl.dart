import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;

  AuthRepositoryImpl(this._remoteDataSource);

  @override
  Stream<User?> get authStateChanges => _remoteDataSource.authStateChanges;

  @override
  User? get currentUser => _remoteDataSource.currentUser;

  @override
  Future<void> signInWithEmailAndPassword(String email, String password) =>
      _remoteDataSource.signIn(email, password);

  @override
  Future<void> createUserWithEmailAndPassword(String email, String password) =>
      _remoteDataSource.register(email, password);

  @override
  Future<void> signOut() => _remoteDataSource.signOut();
}
