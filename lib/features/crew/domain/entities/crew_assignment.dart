class CrewAssignment {
  final String name, role, vehicle, shift, duty;
  final String id;
  const CrewAssignment(
    this.name,
    this.role,
    this.vehicle,
    this.shift,
    this.duty, {this.id = ''}
  );
}
