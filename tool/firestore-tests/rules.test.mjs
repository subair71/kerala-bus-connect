import { readFileSync } from 'node:fs';
import { before, after, beforeEach, test } from 'node:test';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, setDoc, updateDoc, deleteDoc, getDoc, writeBatch } from 'firebase/firestore';
let env;
const bus = { ownerId: 'owner', businessId: 'operator', name: 'Bus', tripCount: 0 };
const trip = {
  ownerId: 'owner', businessId: 'operator', busId: 'bus', busName: 'Bus',
  routeId: 'route', stops: ['A', 'B'], stopIds: ['a', 'b'],
  departureMinutes: 480, stopTimings: { A: 480, B: 510 },
  scheduleRevision: 'r1', offDays: [], published: true,
};
const adjustment = {
  ownerId: 'owner', busId: 'bus', tripId: 'trip', serviceDate: '2026-11-06',
  scheduleRevision: 'r1', delays: { a: 5, b: 10 },
  expectedStopTimings: { A: 485, B: 525 },
};
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-owner-trips',
    firestore: { rules: readFileSync('../../firestore.rules', 'utf8') },
  });
});
after(async () => { await env?.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    await setDoc(doc(db, 'businesses/operator'), { ownerId: 'owner', name: 'Operator' });
    await setDoc(doc(db, 'businesses/other'), { ownerId: 'other', name: 'Other' });
    await setDoc(doc(db, 'buses/bus'), bus);
  });
});
async function createTrip(db) {
  const batch = writeBatch(db);
  batch.set(doc(db, 'services/trip'), trip);
  batch.update(doc(db, 'buses/bus'), { tripCount: 1 });
  return batch.commit();
}
test('owner creates and reopens trip; anonymous passenger reads timetable', async () => {
  const owner = env.authenticatedContext('owner').firestore();
  await assertSucceeds(createTrip(owner));
  await assertSucceeds(getDoc(doc(env.unauthenticatedContext().firestore(), 'services/trip')));
  await assertFails(deleteDoc(doc(owner, 'buses/bus')));
});
test('other account cannot read or mutate bus, claim ownership, or attach trips', async () => {
  const other = env.authenticatedContext('other').firestore();
  await assertFails(getDoc(doc(other, 'buses/bus')));
  await assertFails(updateDoc(doc(other, 'buses/bus'), { ownerId: 'other' }));
  await assertFails(setDoc(doc(other, 'services/injected'), { ...trip, ownerId: 'other' }));
  const owner = env.authenticatedContext('owner').firestore();
  await assertFails(updateDoc(doc(owner, 'buses/bus'), { ownerId: 'other' }));
  await assertFails(setDoc(doc(owner, 'buses/cross-business'), { ...bus, businessId: 'other' }));
});
test('daily changes require the current trip owner and matching date/revision', async () => {
  const owner = env.authenticatedContext('owner').firestore();
  await createTrip(owner);
  await assertSucceeds(setDoc(doc(owner, 'trip_adjustments/trip_2026-11-06'), adjustment));
  await assertSucceeds(setDoc(doc(owner, 'trip_adjustments/trip_2026-11-06'), adjustment));
  await assertFails(setDoc(doc(env.authenticatedContext('other').firestore(),
    'trip_adjustments/trip_2026-11-06'), { ...adjustment, ownerId: 'other' }));
  await assertFails(setDoc(doc(owner, 'trip_adjustments/trip_2026-11-07'), adjustment));
  await assertFails(setDoc(doc(owner, 'trip_adjustments/trip_2026-11-06'),
    { ...adjustment, scheduleRevision: 'stale' }));
  await assertFails(setDoc(doc(owner, 'trip_adjustments/trip_2026-11-06'),
    { ...adjustment, delays: { unknown: 20 } }));
  await assertSucceeds(getDoc(doc(env.unauthenticatedContext().firestore(),
    'trip_adjustments/trip_2026-11-06')));
  await assertSucceeds(deleteDoc(doc(owner, 'trip_adjustments/trip_2026-11-06')));
});
test('managed trips cannot detach from ownership or change schedule without revision', async () => {
  const owner = env.authenticatedContext('owner').firestore();
  await createTrip(owner);
  await assertFails(updateDoc(doc(owner, 'services/trip'), { busId: '' }));
  await assertFails(updateDoc(doc(owner, 'services/trip'), { ownerId: 'other' }));
  await assertFails(updateDoc(doc(owner, 'services/trip'), { stopTimings: { A: 485, B: 515 } }));
  await assertSucceeds(updateDoc(doc(owner, 'services/trip'), {
    stopTimings: { A: 485, B: 515 }, departureMinutes: 485, scheduleRevision: 'r2',
  }));
  await assertFails(setDoc(doc(owner, 'trip_adjustments/trip_2026-11-06'), adjustment));
  const batch = writeBatch(owner);
  batch.delete(doc(owner, 'services/trip'));
  batch.update(doc(owner, 'buses/bus'), { tripCount: 0 });
  await assertSucceeds(batch.commit());
  await assertSucceeds(deleteDoc(doc(owner, 'buses/bus')));
});

test('clients including admin claims cannot forge money or public departure projections', async () => {
  for (const context of [env.unauthenticatedContext(), env.authenticatedContext('owner'),
    env.authenticatedContext('admin', {admin: true})]) {
    for (const collection of ['commissions', 'advertising_orders', 'payouts', 'verified_payments',
      'sponsored_ads', 'platform_config', 'stop_departures', 'departure_projections']) {
      await assertFails(setDoc(doc(context.firestore(), collection + '/injected'), {ownerId: 'owner', active: true, amountPaise: 999999}));
    }
  }
});
test('invalid running statuses are rejected; cancellation retains owner checks', async () => {
  const owner = env.authenticatedContext('owner').firestore();
  await createTrip(owner);
  await assertSucceeds(setDoc(doc(owner, 'trip_adjustments/trip_2026-11-06'), {...adjustment, status: 'cancelled', delays: {}}));
  await assertFails(setDoc(doc(owner, 'trip_adjustments/trip_2026-11-06'), {...adjustment, status: 'gpsTracked'}));
});
