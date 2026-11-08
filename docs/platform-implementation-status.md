# FindMyBus platform implementation status

PR: #21, branch: perf/scalability-foundations.

## Repository findings

Existing: Flutter Web project, feature repositories, Riverpod 3, Firebase Auth,
Firestore, protected Google Places autocomplete callable, passenger manual search,
owner buses/routes/recurring services, date-specific delays, sponsor carousel,
shimmer states, ownership rules, and CI.

Not found in this branch: a nearest-stop/route API client, stop coordinates,
location permission integration, a routing-duration service, an admin dashboard,
advertiser/order/commission/payout workflows, or native Android/iOS project folders.
The existing Places callable provides text autocomplete, not nearby bus stops or
road durations. Its Kerala location bias is not a nearest-stop implementation.

Automatic timetable shifting already exists in TripPlan.shiftDeparture and the
owner editor: positive/negative changes preserve entered stop intervals, missing
times stay missing, overnight times use absolute minutes, and saves are explicit.
Do not introduce a second implementation.

## Implemented in the current increment

Persistent public schedule caching is wired into the existing transit repository.
SharedPreferencesAsync stores one versioned, complete snapshot per Firebase project.
The snapshot includes public route/stop/timetable data already present in services.
It excludes daily delay estimates, GPS coordinates, user searches, financial data,
and private owner account data.

Only complete server-confirmed snapshots without pending writes are persisted.
Partial Firestore offline query snapshots are not promoted into complete results.
Saved records display immediately while the same existing shared server stream
revalidates. The existing notice component identifies cached data as potentially
outdated. Regular timetables stay distinct from daily delay estimates.

Policy: maximum 2 MiB serialized snapshot, maximum offline age 7 days, no offline
result is labelled current. Invalid/future-dated/unknown-schema data is a cache
miss. Oversized new snapshots evict old ones rather than keeping obsolete data.
Writes serialize and coalesce. Owner schedule changes invalidate the local cache;
server snapshots replace the whole saved result, including deletions and empty
results. Old disk reads cannot replace newly arrived server data.

This is a compatibility increment, not completion of the scaling stage: the
all-published-services subscription remains. The existing 30-second Riverpod idle
retention continues to share active requests; no extra Firestore listener was added.
The 7-day limit is an offline retention policy, not a promise of fresh schedules.
Cross-device edits become visible through the existing server stream when online.

## Stage gates and remaining work

| Stage | Status | Remaining gate |
| --- | --- | --- |
| 1. Analyze | Source inventory and key dependency paths reviewed | Identify the claimed nearby API source/contract; runtime audit needs staging |
| 2. Optimize | Query narrowing, snapshot deduplication, persistent cache implemented | Server search read model, accurate cursor pagination, scoped adjustment reads, monitoring and realistic load tests |
| 3. Passenger | Existing manual search and ordered-stop matching preserved | Nearby API contract, permission flow, distance refresh, next departures, timing reports |
| 4. Owner | Existing editing, shifts and delays preserved | Duration suggestions, suspensions, cancellation and full running status |
| 5. Ads | Existing sponsored_ads carousel preserved | Advertiser submission, packages, approval, route/stop/radius/district targeting and frequency limits |
| 6. Revenue | Not implemented | Server transactions, manual payment verification, immutable renewal attribution, commission ledger, refunds and payouts |
| 7. Validate | Incremental regression suite and CI | Full integrated security, financial, pagination, mobile and load validation |

The stages above are not declared complete. No financial or advertising activation
paths should be exposed before their server authorization and emulator tests pass.

## Proposed collection mapping, subject to staged implementation

| Existing or proposed source | Responsibility |
| --- | --- |
| Firebase Auth + existing businesses | Owner identity and businesses; do not duplicate owners |
| buses | Existing bus records |
| routes | Existing route templates |
| services | Existing recurring approved trip schedules; do not duplicate timetables/trips |
| trip_adjustments | Existing service-date delay exceptions; extend for date-specific status |
| sponsored_ads | Existing public ad presentation; extend only with approved public fields |
| stops / stop_departures | Additive stop identity and indexed departure read model; migration required |
| schedule_reports | Proposed passenger timing reports |
| advertisers | Proposed private advertiser/attribution records |
| advertising_packages | Proposed administrator-controlled configuration |
| advertising_orders | Proposed immutable price/commission snapshots and verified payment records |
| commissions / payouts | Proposed server-only financial ledger and settlement records |

None of the proposed new collections or associated functions is deployed by this
increment. Existing Firestore rules and Cloud Functions remain unchanged.

## Financial design constraints for later stages

Prices originate from administrator-controlled packages (initial suggestions:
499/999/1999 INR), not Flutter widgets. Use integer paise, explicit rounding and
immutable order snapshots. Commission defaults to 30% only through configurable
server policy. Renewals retain original referral ownership unless an audited admin
change is made. Payment verification and commission creation must be one idempotent
server transaction per order. Ad approval is separate from payment verification.

For owner-collected payments, retained commission must not also become a second
payout liability. Verify platform remittance and mark commission as retained.
For direct payments, record a payable commission and settle through payout records.
Refunds/cancellations require auditable reversals and must block further activation.
No client-supplied amounts, role flags, success screens or receipt uploads authorize
activation or a payable commission. No automatic recurring charge is planned.

## Deployment and validation

This increment adds shared_preferences. Run flutter pub get and commit its resolved
lockfile. No database migration, collection deletion or Firebase rules deployment
is required for the cache. Web persistence remains best effort: browser storage can
be unavailable or evicted, and the app must continue with the live source.

Tests added for restart round trips, old/corrupt/incomplete data, size bounds,
unknown legacy operating days, deletions, empty results, serialized writes,
offline recovery, stale read races, invalidation, storage errors and cancellation.
Native platform runtime tests cannot be claimed from this web-only repository.

Do not claim support for 10 lakh concurrent users or measured production savings.
Registered-user capacity needs a workload model (DAU, peak concurrency, searches
per user, route skew, update frequency) and a staging project. Track read/write
counts, listener lifetime, bandwidth, function duration, cache hit rate and p95/p99
latency. Use project billing alerts configured in Google Cloud before load tests.
