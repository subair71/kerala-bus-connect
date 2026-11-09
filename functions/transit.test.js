import test from 'node:test';
import assert from 'node:assert/strict';
import {projectDepartures, rowMatches, tokens, shiftDate, distanceKm} from './transit.js';
const service = {published: true, scheduleRevision: 'r1', stops: ['A', 'B', 'C'], stopIds: ['a', 'b', 'c'],
  stopTimings: {A: 1430, B: 1450, C: 1470}, departureMinutes: 1430, offDays: ['Sunday'], routeName: 'A to C'};
test('recurring projections preserve boarding order and next-day operating days', () => {
  const rows = projectDepartures('t', service);
  assert.equal(rows[1].minute, 10);
  assert.ok(!rows[1].keys.includes('Monday|stop|b'));
  assert.ok(rows[1].keys.includes('Sunday|stop|b'));
  assert.equal(rowMatches(rows[1], {from: 'b', to: 'c'}), true);
  assert.equal(rowMatches(rows[1], {from: 'b', to: 'a'}), false);
});
test('daily delays are indexed at expected time, cancellations preserve schedules', () => {
  const daily = {serviceDate: '2026-11-09', scheduleRevision: 'r1', delays: {a: 30}};
  const delayed = projectDepartures('t', service, daily);
  assert.equal(delayed[0].scope, '2026-11-10');
  assert.equal(delayed[0].minute, 20);
  assert.equal(delayed[0].status, 'delayed');
  assert.equal(projectDepartures('t', service, {...daily, status: 'cancelled'})[0].minute, 1430);
  assert.deepEqual(projectDepartures('t', service, {...daily, scheduleRevision: 'old'}), []);
});
test('partial queries remain candidates; date arithmetic and distance are stable', () => {
  assert.ok(tokens('Kunnamkulam').includes('nam'));
  assert.equal(shiftDate('2026-12-31', 1), '2027-01-01');
  assert.equal(distanceKm({latitude: 10, longitude: 76}, {latitude: 10, longitude: 76}), 0);
});
