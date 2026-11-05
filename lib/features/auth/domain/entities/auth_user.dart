import 'package:equatable/equatable.dart';

class AuthUser extends Equatable {
  final String id;
  final String? email;
  const AuthUser({required this.id, this.email});
  @override
  List<Object?> get props => [id, email];
}
