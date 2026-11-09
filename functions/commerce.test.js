import test from 'node:test';
import assert from 'node:assert/strict';
import {commissionFor, packageData, adMatches, platformAction} from './commerce.js';
test('commissions use integer paise and validated administrator rates', () => {
  assert.equal(commissionFor(100000, 3000), 30000);
  assert.equal(commissionFor(49900, 3000), 14970);
  assert.equal(commissionFor(101, 3000), 30);
  assert.throws(() => commissionFor(100, 10001));
  assert.throws(() => commissionFor(-100, 3000));
});
test('package configuration validates coverage and prices', () => {
  assert.throws(() => packageData({name: 'X', pricePaise: -1}));
});
test('targeting requires approval, an actual paid period and geographic/route relevance', () => {
  const ad = {approval: 'approved', paidPeriods: [{start: 10, end: 100}], coverage: 'route', routeIds: ['r'], stopIds: []};
  assert.equal(adMatches(ad, {routeIds: ['r']}, 50), true);
  assert.equal(adMatches(ad, {routeIds: ['other']}, 50), false);
  assert.equal(adMatches(ad, {routeIds: ['r']}, 101), false);
  assert.equal(adMatches({...ad, approval: 'pending'}, {routeIds: ['r']}, 50), false);
  assert.equal(adMatches({...ad, paidPeriods: [{start: 10, end: 100, refunded: true}]}, {routeIds: ['r']}, 50), false);
});
test('unauthenticated financial actions fail before database access', async () => {
  await assert.rejects(platformAction({}, null, {}), {code: 'unauthenticated'});
});
