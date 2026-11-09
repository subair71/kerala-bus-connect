# FindMyBus platform expansion — PR #22

This extends the existing application after PR #21. Existing collection names, owner trip editors, navigation, font, palette, home search layout, Places autocomplete, schedule shifting and return-trip logic remain in use. Routes, Owner, Tracking and Crew now share the home theme and 1200px responsive content boundary. New consoles use the same cards, controls and typography.

## Implemented architecture

- Riverpod remains the state-management system. No setState, legacy state providers, BLoC or GetIt were introduced.
- Existing trip repositories and domain entities now support Scheduled, On Time, Delayed, Cancelled and Completed daily statuses. The regular service can be suspended and reinstated without deleting it.
- Optional arrival times extend existing stopTimings compatibly. Suggestions reuse approved owner timetables, accept missing road durations, configurable factors, general dwell and additional major-stop dwell. They preserve entered times and operate only on a draft. Arrival/departure previews are editable. The existing Review / Save flow is still required.
- The existing callable/App Check client is reused for new backend APIs. Nearby discovery uses a verified Firebase stops registry because this repository contains text autocomplete but no existing nearby-stop endpoint or road-duration API. No coordinates or travel durations are invented.
- The platform feature is gated by PLATFORM_ENABLED until backend deployment and index backfill are verified. Existing behavior remains the fallback deployment mode; an enabled platform does not silently fall back to whole-collection search on API errors.

## Passenger search and caching

Services remain the source of truth. stop_departures is a disposable read projection with one recurring row per supplied stop time, plus rows only for explicitly created daily exceptions. It does not create daily copies of every recurring trip.

Queries use scope, a normalized 1–3 character candidate token combined with operating day, boarding minute and document-ID cursors. The full origin/destination match is checked in the correct stop order; intermediate boarding time determines ordering. Recurring and daily-override streams merge before returning up to four results. Delayed trips whose original scheduled departure has passed remain discoverable through the override stream. Midnight offsets select the correct originating service date.

At most 120 candidates are scanned in one call. A short or empty page with a continuation cursor is not treated as exhaustion: Load more continues scanning. Responses are deduplicated by trip and service date. Updating schedules during a paging session can change positions; Refresh restarts that search. Firestore triggers are eventually consistent, so changes can briefly await projection processing.

The server uses a bounded 10-second, 128-key / 2 MiB public response cache, with in-flight deduplication. Source indexing clears the cache in its own process. Other function instances can remain cached for up to 10 seconds, in addition to trigger delivery latency. No private or financial response is cached there.

The Flutter page cache stores at most 20 first-page searches, up to 256 KiB each, for seven days. It persists regular public schedules, not daily status estimates. Cached results appear immediately with a stale-data notice and refresh in the background. Riverpod shares active requests and retains an idle query for 60 seconds. Owner mutations invalidate the page cache and the existing complete schedule cache. Loading another page preserves current results and uses the existing button shimmer.

Nearby discovery checks permission, has a 10-second GPS timeout, coalesces location requests, and retains GPS only in memory for five minutes. It checks again while the passenger screen is active; it reuses nearby API results for 15 minutes if movement is under 250m. Eight public stop results may be retained for seven days; passenger GPS coordinates are not persisted. Permission denial or unavailable coordinates leave manual search available. Stop data needs administrator verification and coordinates.

## Advertising and financial flows

The existing sponsored_ads collection is reused. Advertisers and ads are managed from the owner portal. Images are supplied as HTTPS URLs. Targeting supports nearby radius, selected routes/stops and district coverage; geographic candidate cells include district borders. Publication requires an administrator approval and a currently paid interval. Sponsored content stays within the existing carousel and is capped to three exposures per installation per local day. Optional impression analytics deduplicate installation/ad/day.

Packages are configured in Firestore. The idempotent seed script creates Basic ₹499, Standard ₹999 and Premium ₹1,999 only where absent, plus a configurable 30% default commission. Widgets contain no package prices.

Orders snapshot server-side prices, duration and commission rate in integer paise:
- Owner collected: the owner retains commission; the verified platform remittance is the platform share. This commission is marked retained and is excluded from payouts.
- Direct payment: FindMyBus verifies the full amount; the commission becomes payable.
- A client receipt cannot activate an ad. Only administrator verification creates a paid interval and the commission ledger entry.
- Each order has at most one commission, deterministic idempotency records and a globally unique verified transaction reference. Concurrent renewals share the pending order.
- Renewals retain the referring owner. An audited administrator attribution change affects future orders; existing financial records remain attributed to their original owner.
- Payout recording accepts only unpaid commissions for one owner, verifies their sum and prevents duplicate payout references.
- Full refunds record a completed external refund reference, reverse unpaid commissions, and mark already paid/retained commissions as recoverable. Historical payment/payout records remain available. Collection of recovery balances is an administrative process.
- No payment gateway, card storage, automatic debit or bank-transfer execution is introduced. Manual verification is the MVP payment mechanism.

Ad lifecycle jobs query the next start/reminder/expiry boundary instead of scanning every ad hourly. Paid intervals are also checked during targeting so an expired ad is never served just because a scheduler is late. Renewal notices are in-app; no email/SMS provider has been added.

## Administration and security

An admin custom claim is assigned only using trusted Admin SDK credentials. The Flutter admin menu is conditional; every privileged callable independently checks the claim.

The admin console covers owners, routes, schedule verification, timing reports, verified stops, advertisers, packages, advertisements, payment verification, commissions, payouts, refunds, attribution and aggregate usage. Owners receive only their own advertising/financial records, with cursor-paged lists. The two exceptions are public package/route/stop choices. Financial balances and monthly movements are maintained transactionally.

No client, including one carrying an admin claim, can directly write the financial collections or departure projections. Privileged mutations go through audited, idempotent server operations. Owner access suspension is also enforced by the existing timetable rules. Owner edits cannot forge administrator review fields. Existing public timetable reads and owner trip authorization remain compatible.

## Collections

Existing source collections retained: businesses, buses, routes, services, trip_adjustments, sponsored_ads, crew_assignments, tracking_previews.

Added where no equivalent existed:
- stops: verified geographic stop registry.
- stop_departures / departure_projections: derived query rows and idempotent projection markers.
- advertisers / advertising_packages / advertising_orders / commissions / payouts / verified_payments: private advertising ledger and configuration.
- platform_config / owner_access / platform_operations / platform_audit: configuration, access and audit controls.
- financial_stats / owner_earnings / platform_metrics: aggregated financial balances and counts.
- schedule_reports / platform_notifications: timing reports and renewal notices.
- usage_dedup / usage_daily / usage_monthly / usage_dimensions / ad_metrics / analytics_summaries: opt-in aggregate analytics.

## Analytics and monitoring

Usage collection is opt-in. It uses a random installation identifier, not an Auth UID, GPS coordinates, contact details or search text. DAU/MAU are explicitly labelled as measured opt-in installations, not all registered people. Search/failure, ad impression/click and known route/stop counters are aggregated into 32 shards. Dimension summaries produce the top observed routes/stops. Financial revenue, renewals and referral balances use verified server transactions, not client events.

Configure a TTL on usage_dedup.expiresAt (40 days); it does not apply to financial audit records. Cloud Function search logs include duration, scanned candidates, returned count and cache classification without raw search text/location. Production log-based latency/error alerts and billing budgets still require project configuration.

## Cloud Functions

Existing placeSuggestions is retained. Added:
searchTimetables, findNearbyStops, managePlatform, listPlatformRecords,
relevantAdvertisements, recordUsage, syncServiceDepartures,
syncDailyDepartures and refreshAdvertisements.

Triggers read the current source inside a transaction to prevent out-of-order delivery from restoring old schedules. Deleting a source removes its projections without deleting unrelated source data.

## Deployment order

Production deployment has not been performed from this session. Firebase is not connected here. Repository changes and emulator success do not mean indexes or functions are deployed.

Use an authenticated environment with access to project findmybus-535ae. Do not paste credentials into GitHub or chat.

1. Review and retain a copy of current production rules and indexes. Confirm the billing plan supports Cloud Functions and Scheduler.
2. Install repository dependencies with npm ci --prefix functions.
3. Set GOOGLE_CLOUD_PROJECT=findmybus-535ae and configure Application Default Credentials.
4. Run node functions/add-indexes.js. It adds missing composites only and never deletes existing ones. Re-run until all report READY.
5. Review the fieldOverrides in firestore.indexes.json. Apply the usage_dedup.expiresAt TTL and payload index exemptions; do not replace unrelated production overrides. The additive script intentionally does not modify these settings.
6. Deploy the reviewed functions and rules with firebase deploy --project findmybus-535ae --only functions:places,firestore:rules.
7. Run node functions/seed-platform.js. Optionally set FINDMYBUS_ADMIN_UID to the existing intended administrator account ID; preserve other custom claims. Sign in again after assigning the claim.
8. Run node functions/backfill.js after index triggers are deployed. It scans sources in bounded batches. Verify projected counts, representative routes, daily exceptions, overnight trips and missing legacy timings.
9. Set platform_config/search.ready=true only after backfill and query/index checks succeed. This flag prevents partial migrations from being treated as complete.
10. Use a staging web build with PLATFORM_ENABLED=true to add verified stop coordinates and route associations through the admin console before public rollout. Old trip-local stop IDs (origin, destination, stop-0) are not global geographical stop identities.
11. Configure Firebase App Check for the production domain and set FIREBASE_APP_CHECK_WEB_SITE_KEY. Retain GOOGLE_PLACES_ENABLED if autocomplete is used.
12. Set the GitHub repository variable PLATFORM_ENABLED=true and run the existing Pages deployment workflow. Until this variable is enabled, the previous search mode remains active.
13. Configure usage TTL, Cloud Monitoring alerts and billing budget alerts. Run a staging test against the real region before increasing function instance limits or enabling broad rollout.

No Firebase collections have been deleted. Existing unmanaged advertisements without paid/approved records need administrative reconciliation before enabling the new advertising workflow; they are not silently granted verified payment status.

## Capacity and cost assumptions

Planning example, not measured production traffic:
1,000,000 registered users; 50,000 DAU; 2,000 peak active sessions; 50 peak search requests/second. These numbers are independent assumptions, not a claim that one million users are concurrent.

A cold first page commonly reads one readiness document, up to two 12-row query batches, and the source/exception documents for candidate verification. Sparse substring/destination matches can scan more, capped at 120 per call with continuation. Hot cache hits avoid those database reads within the serving instance. Query/index-entry charges must also be measured, especially with range ordering and document-ID tie breakers.

Projection storage and index writes grow with the number of recurring stops, not registered passengers. A changed trip with N stops replaces up to N recurring projection documents, plus any explicitly existing daily exceptions. Source fingerprint checks avoid unnecessary projection writes on identical events. Advertising images are externally hosted URLs, so their bandwidth is billed by that host. Opt-in event deduplication and aggregate counters add writes; do not emit events on each keystroke or GPS refresh. Logs, Functions CPU/memory, Scheduler, Firestore storage/index entries, TTL deletes and image bandwidth all need separate cost monitoring.

## Verification and remaining limits

CI executes Dart formatting, architecture checks, analyzer, Flutter tests, layout captures, release web compilation, browser smoke checks, Node unit tests, Firestore rules tests, transactional emulator tests and bounded emulator concurrency workloads. Final counts and measured workload results are recorded in [the validation report](platform-validation.md).

The emulator workload uses synthetic recurring trips, repeated hot queries, diverse route queries and pagination. It is a correctness/performance diagnostic, not a production latency or million-user certification. Network latency, App Check overhead, separate function instances, regional indexes and real dataset distributions require staging measurements. Native Android/iOS project folders are absent; only the existing web target and mobile browser layouts are validated.

Road-duration API integration is not configured; suggestions use existing approved intervals and owner-supplied durations. Nearby discovery requires verified coordinates. Payments/refunds/payouts are manually verified records, not transfers initiated by this software. There is no standalone advertiser account portal, automatic charging, continuous GPS tracking or external notification provider. Existing scheduled timings work independently of GPS.

Production acceptance targets should include correct route ordering and delayed/overnight inclusion, zero cross-owner financial access, zero duplicated commissions, acceptable cache staleness, real-region p95 latency under the chosen peak workload, and a measured monthly cost ceiling. Do not label the deployment ready for one million users until those checks pass.
