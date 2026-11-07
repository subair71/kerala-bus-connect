# Riverpod and rendering performance

Application state remains in Riverpod providers and notifiers. Controllers and focus/animation lifecycles use disposable Flutter hooks; application sources contain no setState, StatefulWidget, StatefulBuilder, useState, useReducer, ChangeNotifier, or legacy state-management packages. CI enforces these boundaries.

Changes:
- Owner businesses, timetables, buses, crew, tracking and daily updates reuse shared live subscriptions during brief tab switches. Idle caches expire after 30 seconds. Account-dependent providers still reset on authentication changes.
- The app shell observes auth events without rebuilding on every event. The home theme is memoized across layout and keyboard changes.
- Find bus and Routes reuse the normalized search index. Departure sorting resolves each boarding time once and uses constant-time exact timing lookups, preserving partial-stop matching, midnight values, missing times, daily adjustments and stable ordering for tied times.
- Owner trips and existing timetable assignments use lazy slivers in the main viewport. Filtering/sorting and daily-adjustment indexing live in providers, independently of busy controls and selected service dates.
- Tracking stops render lazily. Crew searches debounce for 200 ms; shift changes remain immediate. Scroll positions and drag-to-dismiss keyboards are retained.
- Trip route typing rebuilds the affected row, and note typing avoids rebuilding the timeline. The timeline no longer performs intrinsic-height layout. Saving reads the current draft.
- Sponsor auto-scroll, reduced-motion behavior, search bottom sheets, native validation and existing owner operations remain supported.

Validation includes a deterministic 2,000-record comparison: boarding-time lookups fall from 54,924 to 2,000 with identical ordering. Timing printed by this test is diagnostic only; it is not a device FPS or production latency claim. Large-list tests cover 200 owner trips and 500 tracking stops, alongside cache reuse/disposal, account isolation, debouncing and editor updates.

The standard workflow runs formatting, architecture checks, flutter analyze, the complete Flutter test suite, 34 mobile/desktop layout captures, a release web build, and desktop Chrome, Android Chrome and iPhone WebKit browser smoke tests. Physical Android/iPhone frame profiling is not available in this environment.
