import {rollupDimensions} from './analytics.js';
import {getApps, initializeApp} from 'firebase-admin/app';
import {getFirestore, FieldPath} from 'firebase-admin/firestore';
import {onCall, HttpsError} from 'firebase-functions/v2/https';
import {onDocumentWritten} from 'firebase-functions/v2/firestore';
import {onSchedule} from 'firebase-functions/v2/scheduler';
import {searchDepartures, nearbyStops, indexSource} from './transit.js';
import {platformAction, platformList, targetedAds, writeAd} from './commerce.js';
import {recordEvent} from './usage.js';

if (!getApps().length) initializeApp();
const db = getFirestore();
const options = {region: 'asia-south1', enforceAppCheck: true,
  cors: process.env.FUNCTIONS_EMULATOR === 'true' ? true : ['https://subair71.github.io'],
  timeoutSeconds: 30, memory: '256MiB', maxInstances: 10, concurrency: 40};
function callable(handler) {
  return onCall(options, async request => {
    if (!request.app) throw new HttpsError('unauthenticated', 'App verification required.');
    return handler(request);
  });
}
export const searchTimetables = callable(async r => {
  const started = Date.now();
  const result = await searchDepartures(db, r.data);
  console.info(JSON.stringify({metric: 'departure_search', durationMs: Date.now() - started,
    scanned: result.scanned, returned: result.records.length, cache: result.cache}));
  return result;
});
export const findNearbyStops = callable(r => nearbyStops(db, r.data));
export const managePlatform = callable(r => platformAction(db, r.auth, r.data));
export const listPlatformRecords = callable(r => platformList(db, r.auth, r.data));
export const relevantAdvertisements = callable(r => targetedAds(db, r.data));
export const recordUsage = callable(r => recordEvent(db, r.data));
export const syncDailyDepartures = onDocumentWritten({
  document: 'trip_adjustments/{id}', region: 'asia-south1', retry: true,
}, event => indexSource(db, 'trip_adjustments', event.params.id));
export const syncServiceDepartures = onDocumentWritten({
  document: 'services/{id}', region: 'asia-south1', retry: true, timeoutSeconds: 540,
}, async event => {
  await indexSource(db, 'services', event.params.id);
  let cursor;
  // Rebuild existing exceptions, not speculative future trip copies.
  const base = db.collection('trip_adjustments').where('tripId', '==', event.params.id).orderBy(FieldPath.documentId());
  while (true) {
    const page = await (cursor ? base.startAfter(cursor) : base).limit(50).get();
    for (const doc of page.docs) await indexSource(db, 'trip_adjustments', doc.id);
    if (page.size < 50) break;
    cursor = page.docs.at(-1);
  }
});
export async function refreshAds(database, now = Date.now()) {
  // Process only advertisements reaching a start/reminder/expiry boundary.
  // Passenger targeting also checks paid intervals, so expiration never waits on cron.
  while (true) {
    const page = await database.collection('sponsored_ads')
      .where('nextTransitionAt', '<=', now).orderBy('nextTransitionAt')
      .orderBy(FieldPath.documentId()).limit(100).get();
    for (const doc of page.docs) await database.runTransaction(async tx => {
      const current = (await tx.get(doc.ref)).data();
      if (!current || current.nextTransitionAt > now) return;
      writeAd(tx, database, doc.ref, current, {}, now);
      if (current.paidUntil > now && current.paidUntil - now <= 7 * 86400000) {
        tx.set(database.doc('platform_notifications/' + doc.id + '_' + current.paidUntil),
          {ownerId: current.ownerId, adId: doc.id, expiresAt: current.paidUntil,
            message: 'Your advertisement expires within seven days. Renew to continue advertising.'}, {merge: true});
      }
    });
    if (page.size < 100) break;
  }
  const [ads, advertisers] = await Promise.all([
    database.collection('sponsored_ads').where('active', '==', true).count().get(),
    database.collection('advertisers').where('activeAds', '>', 0).count().get(),
  ]);
  await database.doc('platform_metrics/advertising').set({
    activeAds: ads.data().count, activeAdvertisers: advertisers.data().count, measuredAt: now});
}
export const refreshAdvertisements = onSchedule({
  schedule: 'every 60 minutes', region: 'asia-south1', timeoutSeconds: 540,
}, async () => {
  await refreshAds(db);
  await rollupDimensions(db, new Date(Date.now() + 330 * 60000).toISOString().slice(0, 10));
});
