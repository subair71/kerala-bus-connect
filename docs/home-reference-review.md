# Home-screen reference implementation

The latest supplied reference (IMG_2432.png) guides the white canvas, outlined joined search fields, circular swap control on their divider, horizontal date tiles, orange full-width search action, and promotional banner treatment. Native Flutter widgets retain FindMyBus branding and the Find bus, Routes, Owner, Tracking and Crew destinations.

## Search and navigation

- Mobile starts with search. Location-specific sponsored cards follow the form; desktop places them alongside search so results retain usable space.
- The search button is integrated into the form. It and the keyboard Search action open the existing mobile results sheet below 768 logical pixels. Desktop/tablet keep inline results.
- The seven-day strip is a presentation of the existing recurring weekday filter. It does not represent date-specific bookings or availability. Selecting a future day clears the today-only restriction.
- “Filters & frequent stops” contains the original weekday/All Days control, running-today switch, corridor chips and View corridor stops action.
- Swap, clear, field editing, current filter state, nested stop timings, sheet close/back/swipe and the existing feature tabs remain connected to Riverpod.
- The strip uses the Kerala clock, handles month/year boundaries and advances at midnight. Explicit selections and typed stops are preserved.
- Independent storage keys keep horizontal date/chip/ad positions, filter expansion and home scrolling from overwriting one another.

## Data and performance

Firebase configuration, schema, authentication, security rules and write paths are unchanged. Valid live records remain preferred; existing labeled sample fallbacks and recovery behavior are preserved. Real schedules are not populated with fictional times, fares, seat counts or live tracking claims.

Ads remain on home only. They follow the selected boarding location, automatically rotate every five seconds, and retain lifecycle, reduced-motion and interaction pauses. Sample advertisements remain labeled and cannot contact advertisers or write sample IDs to Firebase.

Riverpod, zero application setState, shared subscriptions, debounced typing, explicit-submit flushing, stable fixture IDs, lazy result lists and image caching remain in place. The date selector uses the existing clock subscription; no packages or network requests were added.

## Validation

Architecture checks cover 84 Dart files. Flutter analysis, all 52 tests and 17 layout captures passed before the release pipeline. Tests include live/empty/error/recovering data, sample-write guards, owner repository actions, search/swap/date selection, year rollover, midnight updates, mobile bottom-sheet interactions, 200 lazily rendered services, narrow screens, enlarged text and keyboard visibility.

The release pipeline additionally runs strict formatting, the release web build and desktop Chromium, Android Chromium and iPhone WebKit checks. Production CRUD is not mutated during validation; physical-device performance profiling is not included.

- [Mobile home](screenshots/mobile-search-home.png)
- [Desktop home](screenshots/home-desktop.png)
- [Narrow mobile home](screenshots/home-narrow.png)
- [Mobile results sheet](screenshots/mobile-results-sheet.png)

Screenshots use deterministic, clearly labeled samples. Live content depends on Firebase and the user's filters.
