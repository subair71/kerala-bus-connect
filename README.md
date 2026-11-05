# FindMyBus — Riverpod edition

Fresh feature-first rebuild of Kerala Bus Connect on `feature/riverpod-clean-architecture`.
This branch is separate from the deployed main branch.

## Features

| Feature | Implementation |
| --- | --- |
| Passenger search | Boarding/destination partial search, direction-aware matching, day filters, stop timings |
| Route directory | Debounced search of published timetables |
| Owner authentication | Firebase email/password sign-in and registration |
| Owner management | Create/rename businesses; create/edit/delete routes; generate return routes; publish/edit/delete timetables |
| Tracking | Explicitly labelled timetable demo; no GPS backend |
| Crew | Explicitly labelled sample roster with search and shift filters; no staff backend |

## Feature-first clean architecture

- `lib/app/`: bootstrap, shell and Riverpod navigation.
- `lib/core/`: theme, shared widgets, time utilities and Firebase composition.
- `lib/features/<feature>/domain/`: framework-independent entities, contracts and use cases.
- `lib/features/<feature>/data/`: repository implementations and Firebase or demo adapters.
- `lib/features/<feature>/presentation/`: Riverpod controllers, selectors, pages and widgets.

Shared transit entities and persistence live in `features/timetables`; passenger, route and owner features consume them. Providers are the composition boundary. Widgets invoke provider actions; business validation lives in use cases.

All application state uses Riverpod 3 Notifier, AsyncNotifier and StreamProvider APIs. There is no application `setState`, StatefulWidget, BLoC, GetIt, ChangeNotifier or ValueNotifier. Flutter Hooks only manages text-controller lifecycles; editable text remains inside its controller while semantic form state lives in Riverpod. Framework internals are outside this application-level guarantee.

## Performance measures

- One shared published-timetable subscription, retained for 30 seconds of inactivity across navigation.
- Normalized search index and cached query results, with 200 ms typing debounce.
- Lazily built passenger, route and owner lists; hidden tabs are unmounted.
- Narrow selectors for busy/filter state and memoized business timetable filtering/sorting.
- Automatic disposal of editor state, search timers and inactive streams.
- Owner data and selection recompute when authentication changes.
- Kerala-local timetable calculations independent of the browser's timezone.

These are implemented optimizations, not a measured device FPS or startup-time guarantee. The existing Firestore catalogue still downloads all published services: statewide scale requires indexed server queries/pagination and schema backfill. The current schema and security rules are preserved.

## Development and verification

Use Flutter stable with Dart >=3.11 and Flutter >=3.41.

```sh
flutter pub get
python3 tool/check_architecture.py
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter run -d chrome
flutter build web --release --base-href /kerala-bus-connect/
```

CI checks architecture boundaries, forbidden state APIs, formatting, static analysis, domain/provider/widget tests and a release web build. Tests cover search semantics, lazy rendering with 200 services, stream sharing/disposal/retry, authentication changes, editor lifetimes, route creation, service conflict validation and overnight timings.

Firebase configuration is in `lib/core/config/firebase_config.dart`. Authentication and Firestore adapters use the existing project and collections (`businesses`, `routes`, `services`). Public Firebase client configuration is not a substitute for Firestore access rules.

No demo timetables are silently substituted when Firebase is empty or fails. Empty, loading and retry states are shown. Tracking/crew production integrations and physical-device performance profiling remain separate work.
