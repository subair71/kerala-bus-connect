# Home-screen reference implementation

The supplied mobile screenshot is the visual reference for this update. Native Flutter widgets reproduce its pale lavender canvas, deep-green and mint accents, compact header, stacked stop fields, corridor chips, rounded timetable cards, route-line time bands, advisory panel, and flat five-tab mobile navigation. The desktop layout keeps horizontal search and the existing stop-sequence sidebar.

The original HTML/design-document attachments could not be opened in the execution environment; visual comparison uses the visible screenshot. The small brand tile uses a native bus mark because the original logo artwork is not available in the repository.

## Working controls and data

- Existing debounced search, clear/swap, day filter and running-today filter remain connected to Riverpod.
- Both selected stops receive the reference's green chips.
- “View corridor stops” and “View Stops” open the existing stop-timing sheet.
- The header bell opens the timetable advisory; the account button opens Owner.
- Real schedules, operator names, operating-day status and missing-time handling remain unchanged.
- The current service schema has no fares, seat counts or live GPS. Real records say “Fare unavailable”; known demo IDs have explicitly marked sample fares. The screen never claims live GPS, seats or on-time performance.
- Demo fares are display-only fixtures, selected in a provider, and cannot be shown on real service IDs. No Firebase schema, configuration, security rule or write path changes.
- Location-specific sponsorship appears above home search on mobile and desktop. Clearly labeled demo campaigns appear while live ads are pending, empty or unavailable; matching live campaigns replace them automatically. Multiple ads rotate every five seconds. Reduced-motion, hover/touch and lifecycle pauses remain in place; other screens remain ad-free.

## Validation

Architecture checks enforce Riverpod, clean feature boundaries and zero application `setState`. Validation includes formatting, Flutter analysis, 45 domain/provider/widget tests, 13 screenshot scenarios, a release web build and Chromium/WebKit browser smoke checks.

The tests cover empty/live/failed/recovering queries, missing fields, sample write guards, owner commands through repository doubles, lazy rendering with 200 services, long labels, 320/390/412/768/1440-pixel layouts, up to 2× text scaling and keyboard visibility. Additional home tests verify advisory/corridor actions, real-record sample-fare rejection, midnight zero preservation and explicit demo-fare labeling.

Screenshots below use deterministic, labeled sample data. Runtime results and filter values depend on Firebase data and the selected query.

- [Reference-size mobile home](screenshots/home-reference.png)
- [Desktop home](screenshots/home-desktop.png)
- [Narrow mobile home](screenshots/home-narrow.png)

Physical-device performance profiling and authenticated production CRUD are not covered by these automated checks. Production owner data is not mutated during validation.

## Sample sponsor carousel

The home carousel now precedes search at both breakpoints. Existing read-only café/store/hotel fixtures follow the boarding location. Live errors are identified before showing samples; no sample records are written to Firebase or opened as advertiser websites. Provider and widget checks cover fallback, replacement, five-second rotation, lifecycle disposal and placement above search.

- [Mobile with sample sponsors](screenshots/sponsors-mobile.png)
- [Desktop with sample sponsors](screenshots/sponsors-desktop.png)
