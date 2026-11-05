# Kerala Bus Connect / FindMyBus

Flutter Web application for passenger timetables and bus-owner route management.
State management uses BLoC/Cubit, with repository interfaces and GetIt injection.

## Performance changes

- A lazily created app-scoped PublishedServicesCubit shares one published-services
  subscription between passenger search and the route directory. Its latest
  snapshot survives tab switches; the BlocProvider closes it with the app.
- Each snapshot is normalized and sorted once. Repeated normalized searches reuse
  the last result; text-driven results settle after 200 ms.
- Both passenger lists use SliverList builders so off-screen result cards are
  created as needed.
- Search and owner form controllers have explicit lifetimes and disposal.
  Search field identity remains stable while typing and when swapping stops.
- Owner query streams are replaced only when the repository, owner or business
  changes, rather than on every form-state rebuild.
- Startup no longer waits for anonymous authentication. The checked-in Firestore
  rules allow public timetable reads; owner writes still require authentication.
- Published-stream errors reach a retryable UI instead of being swallowed.

## Validation

```sh
flutter pub get
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
flutter build web --release --base-href /kerala-bus-connect/
```

The validation workflow runs these checks on pull requests and performance
branches. Existing analyzer style warnings are non-blocking; errors fail the job.

## State management decision

Keep BLoC/Cubit for this existing codebase. Authentication and owner commands
already use BLoC; search and shared read state fit Cubits. Riverpod is also a
reasonable choice for a new implementation, but changing libraries is not itself
a performance optimization.

## Scaling and measurement

This pass optimizes subscription lifecycle, client-side filtering and rendering.
It does not yet replace the full published-services query with server-side
stop/day filtering or pagination. Before statewide volume, introduce normalized
stop IDs, suitable Firestore indexes and bounded queries with a data backfill;
a simple limit would silently hide valid journeys.

The existing empty-collection demo dataset remains. Live tracking and fares in
the existing UI still include prototype content.

No device frame-time or production Firestore read-count benchmark is included.
Profile a release/profile build with representative route volume and measure
startup, search latency, scroll frame times and reads before claiming a speedup.
