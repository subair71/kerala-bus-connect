# FindMyBus

Native Flutter web and mobile interface, based on the supplied Stitch references.
This redesign is delivered on `feature/stitch-redesign`.

## Features

| Feature | Behavior |
| --- | --- |
| Find bus | Debounced boarding/destination search, direction and operating-day filters, stop timings |
| Routes | Searchable published timetable directory |
| Owner | Firebase email/password sign-in and registration; business, route, return-route and timetable management |
| Tracking | Route position preview; never presented as live GPS |
| Crew | Searchable duty roster and shift filters |
| Sponsors | Home-only carousel selected by boarding location; no placements in results, directory or stop details |

## Design

The archive `stitch_findmybus_minimal_redesign.zip` contains Aluva mobile/desktop and Thrissur mobile references. The implementation uses their light canvas, deep teal accents, Plus Jakarta Sans typography, white cards, pale input wells, timetable bands and stop timeline. Desktop uses top navigation and a timetable sidebar; mobile uses five bottom tabs and scrolling cards.

The reference's unverified fares, registration numbers, platforms, GPS indicators and ratings are omitted unless supported by the existing feature/data model. Broken remote reference images are replaced with native placeholders. The supplied hotel image is bundled as a compressed JPEG. Plus Jakarta Sans is bundled locally under the SIL Open Font License in `assets/fonts/OFL.txt`.

## Firebase and sample selection

Existing Firebase configuration, authentication, `businesses`, `routes`, `services` and security rules are unchanged.

Providers select an entire live result or an explicitly labelled sample result. They never append fictional buses to a real catalogue. A no-match search in a populated live catalogue stays empty. Failed reads show “Live data unavailable” before sample content; streams replace the fallback when valid data arrives. Empty cache-only snapshots are reported as unavailable until the server responds.

Sample fixtures have stable `demo:` identifiers and consistent businesses/routes/buses/crew/tracking references. Owner previews are read-only. Both domain commands and the Firebase repository reject sample IDs on write paths. Nothing seeds Firebase automatically.

Missing display text uses neutral placeholders. Missing schedule times stay unavailable; valid midnight `0` and boolean `false` remain intact. Unknown operating days cannot satisfy a running-today filter. Publishing requires explicit times for every stop.

Optional, read-only integrations use these collections:

| Collection | Fields used |
| --- | --- |
| `sponsored_ads` | `location` (canonical display name, e.g. Aluva or Thrissur), `active` (boolean), `advertiser`, `title`, `description`, optional HTTPS `imageUrl`, `website` |
| `crew_assignments` | `ownerId` (signed-in owner query), `name`, `role`, `vehicle`, `shift`, `duty` |
| `tracking_previews` | `vehicle`, `stops` (string list), `currentStop` (zero-based index) |

The existing rules do not grant access to these optional collections. This branch deliberately preserves those rules: missing or denied optional data produces labelled previews. Enabling production records requires separately reviewed permissions and data. No location permission or GPS tracking was added. Sample sponsor actions explain the preview instead of contacting an invented advertiser.

## Architecture and performance

Feature-first Clean Architecture: domain contracts/use cases, data adapters/fixtures, presentation providers/widgets. Shared transit data lives in `features/timetables`; providers are the composition boundary.

Riverpod owns application state. No application `setState`, StatefulWidget, BLoC, GetIt, ChangeNotifier or ValueNotifier. Flutter Hooks manages text and page-controller lifecycles.

- One shared published-timetable subscription, retained for 30 seconds of inactivity.
- Cached normalized search index and 200 ms query debounce.
- Lazy passenger, route and owner lists; hidden tabs unmount.
- Narrow state selectors and automatic disposal of timers, controllers and streams.
- Auth-scoped owner and crew reads reset when accounts change.
- Bundled font and compressed image; bounded thumbnail decoding; no blur or animation packages.

The current schema still downloads the published catalogue. Statewide-scale server queries/pagination and device FPS profiling remain outside this visual redesign.

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
