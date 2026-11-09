import test, {before, after} from 'node:test';
import assert from 'node:assert/strict';
import {initializeApp, deleteApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {platformAction, platformList, targetedAds} from './commerce.js';
import {indexSource, searchDepartures, nearbyStops} from './transit.js';
import {recordEvent} from './usage.js';
const enabled = !!process.env.FIRESTORE_EMULATOR_HOST;
let app, db, sequence = 0;
const owner = {uid: 'platform-owner', token: {}};
const admin = {uid: 'platform-admin', token: {admin: true}};
const now = Date.parse('2026-11-09T04:30:00Z');
const call = (actor, action, data, requestId = 'request-' + sequence++) =>
  platformAction(db, actor, {action, data, requestId}, now);
before(async () => {
  if (!enabled) return;
  app = initializeApp({projectId: 'demo-owner-trips'}, 'platform-integration');
  db = getFirestore(app);
  for (const collection of await db.listCollections()) {
    let docs;
    do {
      docs = await collection.limit(400).get();
      const batch = db.batch(); docs.forEach(d => batch.delete(d.ref)); await batch.commit();
    } while (docs.size === 400);
  }
});
after(async () => { if (app) await deleteApp(app); });
async function fixture(workflow) {
  await call(admin, 'configureCommission', {basisPoints: 3000});
  await call(admin, 'savePackage', {id: 'basic', name: 'Basic', pricePaise: 100000,
    durationDays: 30, radiusKm: 3, routeLimit: 2, adLimit: 20, coverage: ['nearby', 'route'], features: 'Local ads'});
  const advertiser = await call(owner, 'registerAdvertiser', {
    name: 'Test shop', category: 'Shop', contact: 'Test receipt contact',
    latitude: 10.5, longitude: 76.2, district: 'Thrissur'});
  const ad = await call(owner, 'submitAd', {
    advertiserId: advertiser.id, packageId: 'basic', title: 'Test sponsored ad', description: 'Test',
    imageUrl: 'https://example.com/ad.jpg', location: 'Thrissur', district: 'Thrissur',
    latitude: 10.5, longitude: 76.2, routeIds: ['route-a'], stopIds: ['stop-a'], coverage: 'route', radiusKm: 3});
  const order = await call(owner, 'createOrder', {adId: ad.id, workflow});
  return {advertiser, ad, order};
}
test('direct payments: verified once, approval required, recurring commission, payout and refund', {skip: !enabled}, async () => {
  const {advertiser, ad, order} = await fixture('direct');
  await assert.rejects(call(owner, 'verifyPayment', {orderId: order.id}), {code: 'permission-denied'});
  await call(owner, 'submitReceipt', {orderId: order.id, receipt: 'Bank receipt'});
  const verification = {orderId: order.id, receivedPaise: 100000, transactionReference: 'BANK-ONE'};
  await Promise.all([call(admin, 'verifyPayment', verification), call(admin, 'verifyPayment', verification)]);
  assert.equal((await db.doc('commissions/' + order.id).get()).data().amountPaise, 30000);
  assert.equal((await db.doc('sponsored_ads/' + ad.id).get()).data().active, false);
  await call(admin, 'reviewAd', {adId: ad.id, approval: 'approved', note: 'Reviewed'});
  assert.equal((await targetedAds(db, {routeIds: ['route-a']}, now)).ads.length, 1);
  assert.equal((await db.doc('advertisers/' + advertiser.id).get()).data().activeAds, 1);
  assert.equal((await db.doc('sponsored_ads/' + ad.id).get()).data().nextTransitionAt, now + 23 * 86400000);
  const renewals = await Promise.all([
    call(owner, 'createOrder', {adId: ad.id, workflow: 'direct'}),
    call(owner, 'createOrder', {adId: ad.id, workflow: 'direct'}),
  ]);
  assert.equal(renewals[0].id, renewals[1].id);
  await call(owner, 'submitReceipt', {orderId: renewals[0].id, receipt: 'Renewal'});
  await call(admin, 'verifyPayment', {orderId: renewals[0].id, receivedPaise: 100000, transactionReference: 'BANK-TWO'});
  const renewal = (await db.doc('commissions/' + renewals[0].id).get()).data();
  assert.equal(renewal.ownerId, owner.uid);
  assert.equal(renewal.amountPaise, 30000);
  await call(admin, 'recordPayout', {commissionIds: [order.id], amountPaise: 30000, reference: 'PAYOUT-ONE'});
  await assert.rejects(call(admin, 'recordPayout', {commissionIds: [order.id], amountPaise: 30000, reference: 'PAYOUT-TWO'}));
  await call(admin, 'refundOrder', {orderId: order.id, reference: 'REFUND-ONE'});
  assert.equal((await db.doc('commissions/' + order.id).get()).data().status, 'recoveryDue');
  assert.equal((await targetedAds(db, {routeIds: ['route-a']}, now)).ads.length, 0);
  assert.equal((await db.doc('advertisers/' + advertiser.id).get()).data().activeAds, 0);
});
test('owner-collected money retains commission without another payable balance', {skip: !enabled}, async () => {
  const {ad, order} = await fixture('ownerCollected');
  const saved = (await db.doc('advertising_orders/' + order.id).get()).data();
  assert.equal(saved.duePaise, 70000);
  await call(owner, 'submitReceipt', {orderId: order.id, receipt: 'Platform share transfer'});
  await assert.rejects(call(admin, 'verifyPayment', {orderId: order.id, receivedPaise: 100000, transactionReference: 'BAD-AMOUNT'}));
  await call(admin, 'verifyPayment', {orderId: order.id, receivedPaise: 70000, transactionReference: 'OWNER-SHARE'});
  assert.equal((await db.doc('commissions/' + order.id).get()).data().status, 'retained');
  await assert.rejects(call(admin, 'recordPayout', {commissionIds: [order.id], amountPaise: 30000, reference: 'DOUBLE-PAYOUT'}));
  await assert.rejects(call({uid: 'other', token: {}}, 'createOrder', {adId: ad.id, workflow: 'direct'}), {code: 'permission-denied'});
  const outsider = await platformList(db, {uid: 'other', token: {}}, {collection: 'advertising_orders'});
  assert.deepEqual(outsider.records, []);
});
test('idempotency rejects changed payloads and duplicate bank references', {skip: !enabled}, async () => {
  await call(admin, 'configureCommission', {basisPoints: 3000}, 'fixed-id');
  await assert.rejects(call(admin, 'configureCommission', {basisPoints: 4000}, 'fixed-id'));
  const {order} = await fixture('direct');
  await call(owner, 'submitReceipt', {orderId: order.id, receipt: 'Duplicate bank transfer'});
  await assert.rejects(call(admin, 'verifyPayment', {orderId: order.id, receivedPaise: 100000, transactionReference: 'BANK-TWO'}));
  assert.equal((await db.doc('commissions/' + order.id).get()).exists, false);
});
test('cursor pages retain delayed departures, reject reverse stop order and preserve ties', {skip: !enabled}, async () => {
  await db.doc('platform_config/search').set({ready: true});
  for (let i = 0; i < 18; i++) {
    const service = {published: true, ownerId: owner.uid, busId: 'bus', routeId: 'route-a',
      scheduleRevision: 'r1', stops: ['Alpha', 'Beta', i % 3 === 0 ? 'Other' : 'Gamma'],
      stopIds: ['a', 'b', 'c'], departureMinutes: 590 + i * 2,
      stopTimings: {Alpha: 590 + i * 2, Beta: 600 + i * 2, [i % 3 === 0 ? 'Other' : 'Gamma']: 620 + i * 2},
      offDays: [], busName: 'Bus ' + i};
    await db.doc('services/page-' + i).set(service);
    await indexSource(db, 'services', 'page-' + i);
  }
  await db.doc('trip_adjustments/page-1_2026-11-09').set({tripId: 'page-1', serviceDate: '2026-11-09', scheduleRevision: 'r1', delays: {a: 30}, status: 'delayed'});
  await indexSource(db, 'trip_adjustments', 'page-1_2026-11-09');
  const records = [];
  let cursor;
  for (let i = 0; i < 20; i++) {
    const page = await searchDepartures(db, {from: 'alpha', to: 'gamma', date: '2026-11-09', cursor}, new Date(now));
    records.push(...page.records); cursor = page.cursor; if (!cursor) break;
  }
  assert.ok(records.some(r => r.id === 'page-1' && r.runningStatus === 'delayed'));
  assert.equal(new Set(records.map(r => r.id)).size, records.length);
  assert.deepEqual(records.map(r => r.boardingMinute), records.map(r => r.boardingMinute).sort((a,b) => a-b));
  assert.equal(records.some(r => r.stops.at(-1) === 'Other'), false);
  assert.deepEqual((await searchDepartures(db, {from: 'gamma', to: 'alpha', date: '2026-11-09'}, new Date(now))).records, []);
  // Reading the newest source makes a delayed retry harmless.
  await db.doc('services/page-2').delete();
  await indexSource(db, 'services', 'page-2');
  await indexSource(db, 'services', 'page-2');
  assert.equal((await db.collection('stop_departures').where('tripId', '==', 'page-2').get()).size, 0);
});
test('nearby discovery uses verified coordinates and distance ordering', {skip: !enabled}, async () => {
  for (const [id, latitude] of [['near', 10.5], ['far', 10.51]]) {
    await call(admin, 'saveStop', {id, name: id, latitude, longitude: 76.2, district: 'Thrissur', routeIds: []});
  }
  const result = await nearbyStops(db, {latitude: 10.5, longitude: 76.2});
  assert.deepEqual(result.stops.map(s => s.id), ['near', 'far']);
});
test('analytics deduplicates concurrent impressions and anonymous measured users', {skip: !enabled}, async () => {
  const event = {event: 'session', installationId: 'installation-test-001', eventId: 'event-testing-001'};
  const results = await Promise.all([recordEvent(db, event, now), recordEvent(db, event, now)]);
  assert.equal(results.filter(r => r.counted).length, 1);
});
