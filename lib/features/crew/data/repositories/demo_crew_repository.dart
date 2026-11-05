import '../../domain/entities/crew_assignment.dart';
import '../../domain/repositories/crew_repository.dart';

class DemoCrewRepository implements CrewRepository {
  const DemoCrewRepository();
  @override
  Stream<List<CrewAssignment>> watch(String ownerId) =>
      Stream.value(assignments());
  List<CrewAssignment> assignments() => const [
    CrewAssignment(
      'Demo driver A',
      'Driver',
      'St. Antony Express',
      'Morning',
      '06:00 AM – 02:00 PM',
    ),
    CrewAssignment(
      'Demo conductor A',
      'Conductor',
      'St. Antony Express',
      'Morning',
      '06:00 AM – 02:00 PM',
    ),
    CrewAssignment(
      'Demo driver B',
      'Driver',
      'Royal Travels',
      'Evening',
      '02:00 PM – 10:00 PM',
    ),
    CrewAssignment(
      'Demo reliever',
      'Driver',
      'Unassigned',
      'Standby',
      'Available for assignment',
    ),
  ];
}
