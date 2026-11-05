import '../entities/crew_assignment.dart';
abstract interface class CrewRepository {
  List<CrewAssignment> assignments();
}
