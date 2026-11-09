// Emulator-only bounded workload. Refuses all production projects/endpoints.
import {initializeApp, deleteApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {performance} from 'node:perf_hooks';
import {indexSource, searchDepartures, queryDepartures} from './transit.js';
if (!/^(127\.0\.0\.1|localhost):\d+$/.test(process.env.FIRESTORE_EMULATOR_HOST ?? '')) {
  throw new Error('Load tests require a local Firestore emulator.');
}
const app = initializeApp({projectId: 'demo-owner-trips'}, 'load');
const db = getFirestore(app);
await db.doc('platform_config/search').set({ready: true});
for (let i = 0; i < 200; i++) {
  const start = 600 + i % 300;
  await db.doc('services/load-' + i).set({published: true, scheduleRevision: 'r1',
    stops: ['LoadOrigin', 'LoadMiddle', 'LoadDestination'], stopIds: ['a','b','c'],
    stopTimings: {LoadOrigin: start, LoadMiddle: start + 10, LoadDestination: start + 30},
    departureMinutes: start, offDays: [], routeName: 'Load test'});
  await indexSource(db, 'services', 'load-' + i);
}
for (const scenario of [{mode: 'cold', concurrency: 10}, {mode: 'shared-cache', concurrency: 10}, {mode: 'shared-cache', concurrency: 25}, {mode: 'shared-cache', concurrency: 50}]) {
  const {mode, concurrency} = scenario;
  const times = [];
  let errors = 0, scanned = 0;
  const started = performance.now();
  await Promise.all(Array.from({length: concurrency}, async () => {
    for (let i = 0; i < 4; i++) {
      const at = performance.now();
      try {
        const result = await (mode === 'cold' ? queryDepartures : searchDepartures)(db, {from: 'loadorigin', to: 'loaddestination', date: '2026-11-09'},
          new Date('2026-11-09T04:30:00Z'));
        if (result.records.length !== 4) throw new Error('Incomplete page');
        scanned += result.scanned;
      } catch { errors++; }
      times.push(performance.now() - at);
    }
  }));
  times.sort((a,b) => a-b);
  const report = {mode, concurrency, requests: times.length, errors,
    durationMs: Math.round(performance.now() - started),
    p50Ms: Math.round(times[Math.floor(times.length * .5)]),
    p95Ms: Math.round(times[Math.floor(times.length * .95)]), scanned};
  console.log('EMULATOR_LOAD_RESULT=' + JSON.stringify(report));
  if (errors) process.exitCode = 1;
}
await deleteApp(app);
