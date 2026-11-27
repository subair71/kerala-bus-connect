# FindMyBus

The Flutter app follows the 25 mobile screens in the FindMyBus design guide. Find bus, Departures, Routes, Saved and More share the passenger navigation. More opens owner access and the crew roster. The owner workspace uses a three-step trip editor and a separate service-date adjustment form.

Passenger journeys and operator views live under `lib/features/journeys/presentation/screens`. Data comes from the existing Riverpod repositories. Maps are schematic, boarding and arrival times use Kerala time, and sample timetables and assignments carry labels.

Run `flutter test test/pdf_screens_test.dart` to exercise the 25 screens from the app entry point. Run `flutter test tool/capture_screenshots.dart --update-goldens` to capture the same paths using deterministic test records.

## Firebase and sample selection

Existing Firebase configuration and authentication are retained. `services` remains the published timetable catalogue. Bus management adds `buses`; date-specific operational changes use `trip_adjustments`. Deploy the updated `firestore.rules` before releasing the owner dashboard. See [owner trip dashboard](docs/owner-trip-dashboard.md) for behavior, schema and release checks.

Providers select an entire live result or an explicitly labelled sample result. They never append fictional buses to a real catalogue. A no-match search in a populated live catalogue stays empty. Failed reads show “Live data unavailable” before sample content; streams replace the fallback when valid data arrives. Empty cache-only snapshots are reported as unavailable until the server responds.

Sample fixtures have stable `demo:` identifiers and consistent businesses/routes/buses/crew/tracking references. Both domain commands and the Firebase repository reject sample IDs on write paths. Nothing seeds Firebase automatically.

Missing display text uses neutral placeholders. Missing schedule times stay unavailable; valid midnight `0` and boolean `false` remain intact. Unknown operating days cannot satisfy a running-today filter. Publishing requires explicit times for every stop. Managed trips have stable stop IDs and schedule revisions; regular timetable edits invalidate stale daily adjustments.

Optional, read-only integrations use these collections:

| Collection | Fields used |
| --- | --- |
| `sponsored_ads` | `location` (canonical display name, e.g. Aluva or Thrissur), `active` (boolean), `advertiser`, `title`, `description`, optional HTTPS `imageUrl`, `website` |
| `crew_assignments` | `ownerId` (signed-in owner query), `name`, `role`, `vehicle`, `shift`, `duty` |
| `tracking_previews` | `published` (true for a public position), `vehicle`, `stops` (string list), `currentStop` (zero-based index) |

The existing rules do not grant access to these optional collections. Missing or denied optional data produces labelled previews. Enabling production records requires separately reviewed permissions and data. Nearby searches can request the device location. Sample advertisements do not open an external website.

## Architecture and performance

Feature-first Clean Architecture: domain contracts/use cases, data adapters/fixtures, presentation providers/widgets. Shared transit data lives in `features/timetables`; providers are the composition boundary.

Riverpod owns application state. No application `setState`, StatefulWidget, BLoC, GetIt, ChangeNotifier or ValueNotifier. Flutter Hooks manages text and page-controller lifecycles.

- One shared published-timetable subscription, retained for 30 seconds of inactivity; daily adjustments share a separate subscription per selected service date.
- Cached normalized search index and 200 ms query debounce.
- Lazy passenger and route lists; owner trips grouped by selected bus; hidden tabs unmount.
- Narrow state selectors and automatic disposal of timers, controllers and streams.
- Auth-scoped owner and crew reads reset when accounts change.
- Bundled font and compressed image; bounded thumbnail decoding; no blur or animation packages.

The indexed passenger reader uses bounded cursor pages. See [passenger capacity](docs/passenger-capacity.md) for rollout flags, measurements and staging checks.

## Validation

```sh
flutter pub get
python3 tool/check_architecture.py
dart format --output=none --set-exit-if-changed lib test tool/capture_screenshots.dart
flutter analyze
flutter test
flutter test tool/capture_screenshots.dart --update-goldens
flutter build web --release --base-href /kerala-bus-connect/
```

CI checks architecture, formatting, analysis, domain/provider/widget behavior, eight screenshot layouts and the release web build. Browser smoke tests open the compiled application at desktop/mobile sizes and check navigation and ad placement. Artifacts are retained for 14 days.

Tests include populated/empty/error/recovery states, no sample/live mixing, missing numeric/boolean fields, sample-write guards, owner operations through repository doubles, lazy rendering with 200 services, controller preservation, 320/390/768/1440-pixel layouts, long text, keyboard visibility, stream disposal and authentication changes.

Production owner accounts are not used for test writes. Physical Android/iOS devices and production authenticated CRUD require a separate acceptance run; this branch does not deploy or merge itself.

## Passenger app and sample data

The [one-million-user architecture](docs/passenger-capacity.md) describes the production search path, capacity assumptions, verification results and staged release.

The five passenger tabs are Find bus, Departures, Routes, Saved and More. The map is a stop diagram. Nearby distances use the existing location service when the platform callable functions are enabled. Bookmarks are stored on the device. Departure reminders use the selected service date in Kerala time. On Android the OS can defer an alert, and web passengers can import a calendar event.

Open **More → Sample routes** for five illustrative services, including an independent return trip. The screen identifies a Firestore or bundled catalogue. To populate Firestore using Application Default Credentials with write access to the target project:

```bash
npm ci --prefix functions
GOOGLE_CLOUD_PROJECT=findmybus-535ae node functions/seed-samples.js
```

The script verifies five documents in `sample_services` and three fruits in `sample_fruits`. It only creates missing documents. The transit app reads the sample services. For local seeding, set `FIRESTORE_EMULATOR_HOST` and use a `demo-` project ID. Deploy the included Firestore rules to enable the public sample timetable reader.

Web uses the existing Firebase app. Register Android and iOS apps for `com.bilvok.findmybus` in the same project. Supply the Android app ID and API key via `--dart-define=FIREBASE_ANDROID_APP_ID=...` and `--dart-define=FIREBASE_ANDROID_API_KEY=...`, or place the downloaded `google-services.json` in `android/app/`. For iOS use the corresponding `FIREBASE_IOS_APP_ID` and `FIREBASE_IOS_API_KEY` defines, or include the downloaded `GoogleService-Info.plist` as a Runner resource in Xcode. Store builds require the publisher’s release signing configuration.
