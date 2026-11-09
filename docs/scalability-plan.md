# FindMyBus scalability audit and incremental plan

This describes the first increment. See [current implementation status](platform-implementation-status.md)
for the subsequent persistent-cache and scoped-adjustment changes and the expanded platform scope.

Audit baseline: `3154291d64476589c97d286c63fd8e73bfbc06fa`.
This is an initial optimization increment, not a claim of capacity for one million users.

## Existing architecture

The current project already uses feature-based repositories, Riverpod 3 providers,
AsyncNotifier actions, shared StreamProviders, idle retention (30 seconds),
200 ms passenger search debounce, 350 ms Places debounce, lazy lists, and shimmer
states. These should be extended rather than replaced.

The repository tree, data sources, models, search/order logic, owner transactions,
provider dependencies, Firestore rules, and validation configuration were inspected.
No production database, index inventory, traffic measurements, or Firebase billing
data were available. A complete runtime/UI audit has not been performed.

## Priorities

| Priority | Finding | Next implementation and acceptance condition |
| --- | --- | --- |
| P0 | Every passenger subscribes to all published `services`. Search and directory use the complete client index; autocomplete also derives stop labels from it. | Introduce an additive server search read model plus stop directory. Compare every supported query against the existing implementation before switching readers. Keep existing documents compatible. |
| P0 | Passenger filtering permits case-insensitive substring matching and requires origin before destination. Ordering uses boarding-stop expected times after daily delays. | Do not add `limit` to the existing catalog. Cursor order must match final boarding order, including delay changes and stable ID tie-breakers. Test matching buses beyond the first page and changed ordering between pages. |
| P0 | `watchAdjustments(date)` subscribes to all Kerala adjustments for that date. | Scope realtime updates to matching trip IDs (bounded batches), and owner updates to the selected owner/business. Account for deletion/reset and scheduleRevision mismatch. Avoid one listener per result card. |
| P1 | Snapshot metadata can repeat equivalent schedule records and rebuild the search index. | This increment suppresses equivalent lists after model mapping. Errors reset comparison state so unchanged recovery data is delivered. |
| P1 | Each business bus watcher reads all buses for the owner and filters locally. | This increment adds the businessId predicate while retaining the owner predicate and defensive filter. |
| P1 | Sponsor queries read inactive ads. Bus rename reads all related trips before enforcing the existing 400-trip maximum. | This increment filters active sponsors on the server and bounds the rename guard to 401 documents. |
| P1 | No explicit persistent web cache policy, freshness envelope, or complete-query manifest exists. | Persist public query results with schema version, normalized query, service date, fetchedAt, completeness, and LRU size bounds. Start with a proposed 5-minute schedule TTL; validate against freshness needs. Never treat partial offline SDK results as a complete search. Keep errors distinct from confirmed empty results. |
| P1 | Existing streams propagate owner updates, but any future TTL/query cache will require invalidation. | Invalidate both old and new route keys after successful edits, deletes, publication changes, and delays. Use versioned server invalidation for other devices. Prevent in-flight old requests from restoring stale entries. |
| P2 | No app performance monitoring dependency or workload harness is present. | Measure search/startup p50/p95/p99, reads per search, cache hit rate, listener count, retries, memory, frame timings, and update-to-passenger delay. Do not log raw searches or owner identifiers. |
| P2 | One million registered users does not specify concurrent load. | Define DAU, peak concurrent sessions, searches/session, route skew, and owner update rate. Exercise a staging project with bounded ramp-up, quotas and a cost ceiling; emulator tests do not prove production capacity. |

## Changes in this increment

- Timetable streams suppress consecutive equal value lists. All existing models,
  streams, navigation, screen content and business rules remain in place.
- The transformer keeps state per binding, forwards errors and cancellation, and
  re-emits identical records after an error. Order changes remain observable.
- Owner bus queries include both ownerId and businessId.
- Sponsor queries include location and active=true.
- Bus rename reads at most 401 related services before applying its existing
  maximum of 400. The ownership transaction and all write semantics are unchanged.

These are expected operation-count improvements, not measured latency claims:
for an owner with B total buses and b in the selected business, the bus query
matches b instead of B documents. For a location with A ads and a active ads,
the sponsor query matches a instead of A. For a bus with T trips, the preliminary
rename query returns at most min(T, 401) documents. Empty-query minimum charges
and index reads mean these are not exact billing estimates.

Deduplication still maps and compares records; it avoids repeated downstream
index construction and widget notifications, not Firestore network reads.
The full-catalog listener remains the principal scaling limitation.

## Validation

Added regression tests cover duplicate schedules, edits, deletion, ordering,
recovery after errors, independent stream bindings, and cancellation.
The existing suite covers passenger search, journey dates, owner schedule
transactions, revision conflicts, provider reuse, and layouts.

The local execution environment was unavailable during authoring. Run repository
CI for formatting, analysis, Flutter tests, web build and browser smoke tests.
No new pagination, persistent-cache/offline, production monitoring, or concurrent
load validation has been completed in this increment. Do not deploy on the basis
of this document alone.

Before enabling new compound query shapes in production, verify indexes against
the staging database; index configuration is not currently checked into this repo.
Firestore can merge equality indexes, but any required additional index must be
built before rollout. No indexes, rules or collections are deleted or deployed
by this increment.

## Required regression matrix for later increments

- Case/substring stop matching, origin-before-destination, unknown operating days,
  intermediate boarding, equal boarding times, overnight minutes, daily delays.
- First/middle/final cursor pages, empty filtered pages, no skipped/duplicated IDs,
  relevant upcoming bus beyond the first page, updates/deletes between pages.
- Cold start, warm TTL hit, TTL expiry, offline restart, corrupt/evicted cache,
  stale request completion after owner save, and cross-device schedule changes.
- Owner switch/sign-out, create/edit/delete/return trips, renamed buses, revision
  conflicts, daily reset, and partial-network failures.
- Staging load with hot routes, random routes, simultaneous reads and owner edits,
  cold/warm caches, retries and disconnections. Record workload and measured
  results before making capacity or cost claims.

References: [Firestore cursors](https://firebase.google.com/docs/firestore/query-data/query-cursors),
[offline data](https://firebase.google.com/docs/firestore/manage-data/enable-offline),
[Riverpod disposal](https://riverpod.dev/docs/concepts2/auto_dispose).
