import '../entities/crew_assignment.dart';
abstract interface class CrewRepository {
  Stream<List<CrewAssignment>> watch(String ownerId);
}
