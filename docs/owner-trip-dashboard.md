# Owner bus and trip dashboard

The owner portal uses the existing Flutter, Riverpod, Firebase Auth and Firestore stack.
Select a business, add or select a bus, then create a trip. Each trip owns its ordered
stop snapshot and times. The route/timetable tools remain available for older records;
"Assign existing timetables" moves an existing timetable into bus management when saved.

## Timing behavior

- Route names and travel times come from the owner. No sample geography is seeded.
- The trip editor has route, timings and review steps. Drag handles and named move
  buttons reorder stops. All stops, including endpoints, are editable.
- Times are minutes from midnight of the service date. Owners explicitly choose
  Next day for overnight stops; backward times on the same day are rejected.
- A departure edit shifts configured times by its delta. Missing times remain missing.
- Return generation reverses all stops and travel intervals into an unsaved, independent trip.
- Daily delays are nonnegative minutes attached to stable stop IDs. Expected time
  is regular time plus the sum of delays through that stop. Saves replace values,
  never increment them, so retries, corrections and removal are idempotent.
- A service date always means the date the trip begins, including overnight stops.
- A schedule revision prevents applying old delays to changed stop order or timings.
  Owners must review daily adjustments after changing the regular schedule.

## Persistence and authorization

New collections: buses and trip_adjustments. Existing services remain the passenger
catalogue; managed services add busId, stopIds and scheduleRevision. Regular stopTimings
remain unchanged by daily updates. Adjustments use one document per trip and service
date, with delays and calculated expectedStopTimings. Passenger search subscribes to the
selected date, derives expected times from saved delays, and sorts by boarding time.

Transactions recheck ownership and schedule revisions before saving. Firestore rules
check bus, business and trip ownership, prevent ownership reassignment, and reject stale
daily writes. Bus trip counts prevent deleting buses that still have trips.

Publish firestore.rules to the existing Firebase project before releasing this UI.
The GitHub Pages deployment does not deploy Firestore rules. No production records are
seeded or migrated automatically. Editing and saving a legacy timetable performs its
explicit association with the selected bus.

## Verification

flutter test test/trip_schedule_test.dart
flutter test test/trip_dashboard_test.dart
flutter test test/trip_passenger_test.dart

The test suite covers configured intervals, return independence, missing/invalid times,
midnight shifts, cumulative/corrected/removed delays, repository save/reopen behavior,
revision conflicts, date isolation, mobile layout and passenger integration.
The separate trip-rules workflow uses the Firestore emulator to verify owner access,
cross-account rejection, stale revisions, daily replacement and passenger reads.

Authenticated production smoke testing and physical iOS/Android checks remain release
acceptance steps. Automated tests use fake Firestore and the emulator.
