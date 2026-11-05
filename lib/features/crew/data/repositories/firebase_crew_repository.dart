import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/data/display_fields.dart';
import '../../domain/entities/crew_assignment.dart';
import '../../domain/repositories/crew_repository.dart';

class FirebaseCrewRepository implements CrewRepository {
  final FirebaseFirestore firestore;
  const FirebaseCrewRepository(this.firestore);
  @override
  Stream<List<CrewAssignment>> watch(String ownerId) => firestore
      .collection('crew_assignments')
      .where('ownerId', isEqualTo: ownerId)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs.map((doc) {
          final data = doc.data();
          return CrewAssignment(
            displayText(data['name'], 'Name unavailable'),
            displayText(data['role'], 'Role unavailable'),
            displayText(data['vehicle'], 'Vehicle unavailable'),
            displayText(data['shift'], 'Shift unavailable'),
            displayText(data['duty'], 'Duty unavailable'),
          );
        }).toList(),
      );
}
