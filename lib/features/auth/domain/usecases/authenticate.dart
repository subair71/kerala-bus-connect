import '../../../../core/errors/app_failure.dart';
import '../repositories/auth_repository.dart';

class Authenticate {
  final AuthRepository repository;
  const Authenticate(this.repository);

  Future<void> call({required String email, required String password, required bool register}) {
    final address = email.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(address)) {
      throw const AppFailure('Enter a valid email address.');
    }
    if (password.length < 6) {
      throw const AppFailure('Use a password with at least 6 characters.');
    }
    return register ? repository.register(address, password) : repository.signIn(address, password);
  }
}
