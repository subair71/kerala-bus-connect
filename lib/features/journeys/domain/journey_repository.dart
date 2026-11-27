import '../../timetables/domain/entities/service_entity.dart';
import 'journey_filters.dart';

typedef SampleCatalogue = ({List<ServiceEntity> records, bool cloud});

abstract interface class JourneyRepository {
  Future<List<SavedJourney>> readBookmarks();
  Future<void> writeBookmarks(List<SavedJourney> items);
  Future<SampleCatalogue> samples();
  Future<ServiceEntity?> timetable(
    String id,
    String date, {
    required bool regular,
  });
}
