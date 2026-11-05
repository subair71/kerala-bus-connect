import '../errors/app_failure.dart';

bool isSampleId(String? id) => id?.startsWith('demo:') ?? false;

void requireLiveIds(Iterable<String?> ids) {
  if (ids.any(isSampleId)) {
    throw const AppFailure(
      'Sample data is read-only. Create your own business and route to publish a timetable.',
    );
  }
}
