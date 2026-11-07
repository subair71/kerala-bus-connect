# Google Places autocomplete

Google place suggestions are available in passenger origin/destination, the routes directory, route endpoints and intermediate stops, and every stop in the owner trip editor. Route names, business names, bus names and crew names are not place inputs.

Existing timetable stop names appear first. Selecting a Google suggestion uses its short name, not its full address. Only an exact case-insensitive match is normalized to an existing timetable label; the app does not guess that two different stops are equivalent. Selecting a place does not imply that a bus serves it. Manual entry, clear, swap, validation and all existing writes remain available. Intermediate-stop autocomplete replaces only the comma-delimited stop at the caret.

## Architecture and performance

The feature has domain entities/repository interfaces, a Firebase callable adapter and Riverpod providers. Native Flutter RawAutocomplete supplies keyboard navigation and overlay positioning; Flutter hooks dispose text/focus resources. There is no application setState.

Queries have a 350 ms debounce, a three-character minimum for Google, bounded responses and timeouts. Each field cancels its pending debounce on focus loss/disposal and ignores stale responses. No Google requests run on startup, on unfocused field changes, or while an IME is composing text. Existing timetable suggestions work with two characters. Google content stays transient; no suggestions, addresses or coordinates are persisted or used to seed Firebase. Owner-confirmed stop names remain ordinary editable form input.

The server calls Places API (New) Autocomplete only, with an India restriction and Kerala bias. Only prediction IDs, main text and secondary text are requested. No map, location permission, geocoding or Place Details call is needed. Consequently requests deliberately omit session tokens and use **per-request Autocomplete billing**; do not describe them as discounted completed sessions. If the app later needs coordinates/details, add correctly terminated sessions then.

## Activation (currently blocked by billing)

A read-only inspection on 7 November 2026 found Places API (New) and Maps JavaScript API enabled in project `findmybus-535ae`, but **no billing account linked**. Only the auto-created Firebase browser key existed. No billing settings, keys or Firebase security rules were changed by this implementation. The integration defaults to disabled until configured.

1. Link a billing account to the existing project / enable the Firebase Blaze plan. Review Google Places pricing and set a conservative Places Autocomplete requests-per-minute quota. Budget alerts are notifications, not spending caps.
2. Create a **dedicated server key** restricted to Places API (New). Do not reuse or modify the Firebase browser key. Keep it in Secret Manager, never a Dart define, web bundle, source file or GitHub log. Use IP restrictions if deploying with fixed egress.
3. Register the existing web app with Firebase App Check using reCAPTCHA v3 and authorize `subair71.github.io`. The site key is public; the secret belongs in the App Check registration. Native builds need their own Firebase app registrations and App Check providers (Play Integrity / App Attest with DeviceCheck fallback).
4. With the Firebase CLI authenticated to the project, run:

```sh
npm ci --prefix functions
firebase functions:secrets:set GOOGLE_PLACES_API_KEY --project findmybus-535ae
firebase deploy --only functions:places --project findmybus-535ae
```

The secret command prompts securely for the Maps server key. The `places` codebase contains only `placeSuggestions` in `asia-south1`. Deploying this codebase does not deploy Firestore rules or touch collections. The function requires a valid App Check token, validates input, fixes the upstream endpoint and fields, strips unnecessary response data and sanitizes failures. App Check lets passengers search without creating an account. Do not disable enforcement for production.

5. Add repository **Actions variables**, then run Deploy Flutter Web:
   - `GOOGLE_PLACES_ENABLED=true`
   - `FIREBASE_APP_CHECK_WEB_SITE_KEY=<public reCAPTCHA site key>`

The deploy workflow passes these values to Flutter. Before enabling production, verify the callable with a real attested app, confirm Google suggestions and attribution, and exercise an unavailable response. To disable Google requests immediately on the next deployment, set `GOOGLE_PLACES_ENABLED=false`.

For a native release, pass `--dart-define=GOOGLE_PLACES_ENABLED=true` and configure that platform's Firebase app first. This repository currently contains a web target, not Android/iOS host projects; browser mobile checks do not replace native device validation.

## Validation

Run `python3 tool/check_architecture.py`, `flutter analyze`, `flutter test`, `npm test --prefix functions`, and the existing release web/browser checks. Places tests cover debounce, stale responses, disposal, disabled configuration, missing/empty fields, failures/recovery, short-name selection, comma-delimited edits, keyboard selection, and narrow layouts with the keyboard visible.

The regular test build keeps Google disabled and injects fake responses for Places tests; it does not consume a live API quota. Actual billing, App Check and Google credentials must be validated after activation. No live Google success should be claimed before that.

Official references:
- https://developers.google.com/maps/documentation/places/web-service/place-autocomplete
- https://developers.google.com/maps/documentation/places/web-service/session-pricing
- https://developers.google.com/maps/documentation/places/web-service/policies
- https://developers.google.com/maps/api-security-best-practices
- https://firebase.google.com/docs/app-check/cloud-functions
