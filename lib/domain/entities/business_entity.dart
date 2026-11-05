import 'package:equatable/equatable.dart';

class BusinessEntity extends Equatable {
  final String id;
  final String ownerId;
  final String name;

  const BusinessEntity({
    required this.id,
    required this.ownerId,
    required this.name,
  });

  @override
  List<Object?> get props => [id, ownerId, name];
}
