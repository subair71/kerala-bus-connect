# Platform validation — PR #22

Validation uses GitHub Actions because this editing environment does not provide a Flutter/Node execution workspace. No production Firebase data was read or changed.

## Checks

| Check | Result |
| --- | --- |
| Architecture guard | No setState or presentation-layer Firebase access introduced |
| Flutter analyzer | No issues |
| Flutter unit/widget/regression suite | 139 passing tests |
| Responsive layout captures | 43 passing captures |
| Release Flutter Web compilation | Passed |
| Browser smoke | Desktop Chromium, Android Chrome emulation and iPhone Safari/WebKit emulation passed startup, navigation and reload |
| Backend unit tests | 16 passed; 8 emulator-only tests skipped here and run in the integration job |
| Firestore authorization rules | 7 passed |
| Transactional emulator integration | 8 passed |

Native Android/iOS binaries were not tested: the existing repository has no native project folders. Mobile-browser emulation is not a physical-device GPS/permission test. New server flows were tested with the emulator and provider fakes; production App Check and regional-index behavior still need staging acceptance.

The suite covers route order, cursor continuation, delayed services, overnight service dates/countdowns, legacy timings, offline cache persistence and invalidation, cache namespace isolation, request deduplication, permission-denied manual fallback, owner timing shifts/suggestions, financial authorization, payment verification, concurrent renewals, payout/refund behavior, attribution, ad targeting and analytics deduplication.

Functional verification runs:
- [Flutter and browser checks](https://github.com/subair71/kerala-bus-connect/actions/runs/42558610923)
- [Backend unit checks](https://github.com/subair71/kerala-bus-connect/actions/runs/42558610918)
- [Rules, transactions and bounded load](https://github.com/subair71/kerala-bus-connect/actions/runs/42558610917)

The PR Checks tab is authoritative for the final formatted commit.

## Measured emulator workload

Measured on GitHub's Linux runner with a local Firestore emulator, calling the query function directly in one Node process. The fixture includes 200 trips on a common route and 80 trips across eight other routes. The mixed workload alternates first/second pages. This is not an HTTP, App Check, multi-instance or production-region benchmark.

| Scenario | Concurrent workers | Requests | Errors | p50 ms | p95 ms | Candidates processed |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| cold | 10 | 40 | 0 | 8250 | 9271 | 160 |
| shared-cache | 10 | 40 | 0 | 0 | 1205 | 4 |
| shared-cache | 25 | 100 | 0 | 0 | 0 | 0 |
| shared-cache | 50 | 200 | 0 | 0 | 0 | 0 |
| mixed-routes | 50 | 200 | 0 | 3085 | 7341 | 64 |

For 40 identical requests, short-lived server caching/shared in-flight work reduced processed candidates from 160 to 4. Candidate counts are not billed-read counts: queries fetch bounded batches, and source/exception verification adds reads. Zero-millisecond warm-cache timings are rounded in-process measurements and exclude all network overhead.

The cold and mixed-route results remain too slow to use as production acceptance evidence. A deployed staging test must measure p50/p95/error rate with actual geographic/route distribution, server instance separation, cold starts, varying query keys, sparse matches, source updates during pagination and regional indexes. Record Firestore billed reads/writes and function/logging cost under that workload.

## Deployment status and acceptance gate

Firebase indexes, functions, rules, seeded packages, verified stop coordinates and production budgets were **not deployed or configured in this session**. PLATFORM_ENABLED remains false by default.

Follow [the deployment guide](platform-expansion.md#deployment-order). The additive index script never deletes existing indexes. Set search readiness only after the projection backfill and representative query checks pass. Authenticate the intended administrator, verify App Check, check both manual-payment workflows and review policy, then enable a staged web build.

The architecture targets a planning example of one million registered users, 50,000 DAU, 2,000 peak active sessions and 50 peak searches/second. These are assumptions, not measured capacity. The deployment must not be described as certified for one million users until staging latency, correctness and cost targets are met.
