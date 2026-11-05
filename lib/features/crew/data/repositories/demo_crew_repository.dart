import '../../domain/entities/crew_assignment.dart';
import '../../domain/repositories/crew_repository.dart';

class DemoCrewRepository implements CrewRepository {
  const DemoCrewRepository();
  @override
  List<CrewAssignment> assignments() => const [
    CrewAssignment('Demo driver A', 'Driver', 'KL-07-DEMO-01', 'Morning', '06:00 AM – 02:00 PM'),
    CrewAssignment('Demo conductor A', 'Conductor', 'KL-07-DEMO-01', 'Morning', '06:00 AM – 02:00 PM'),
    CrewAssignment('Demo driver B', 'Driver', 'KL-07-DEMO-02', 'Evening', '02:00 PM – 10:00 PM'),
    CrewAssignment('Demo reliever', 'Driver', 'Unassigned', 'Standby', 'Available for assignment'),
  ];
}
