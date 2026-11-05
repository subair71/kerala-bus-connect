import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/business_entity.dart';

class BusinessModel extends BusinessEntity {
  const BusinessModel({
    required super.id,
    required super.ownerId,
    required super.name,
  });

  factory BusinessModel.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final data = snap.data() ?? {};
    return BusinessModel(
      id: snap.id,
      ownerId: data['ownerId']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'ownerId': ownerId, 'name': name};
}
