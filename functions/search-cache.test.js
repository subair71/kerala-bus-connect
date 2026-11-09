import test from 'node:test';
import assert from 'node:assert/strict';
import {SearchCache} from './search-cache.js';
test('coalesces requests, expires and invalidates source changes', async () => {
  let now = 0, calls = 0;
  const cache = new SearchCache({now: () => now, ttl: 10});
  const load = async () => { calls++; return {records: [calls], scanned: 4}; };
  const results = await Promise.all([cache.get('a', load), cache.get('a', load)]);
  assert.equal(calls, 1);
  assert.deepEqual(results[0].records, results[1].records);
  assert.equal((await cache.get('a', load)).scanned, 0);
  now = 11; await cache.get('a', load); assert.equal(calls, 2);
  cache.clear(); await cache.get('a', load); assert.equal(calls, 3);
});
test('errors are never cached and bounded entries are evicted', async () => {
  const cache = new SearchCache({maximum: 1});
  await assert.rejects(cache.get('a', async () => { throw new Error('network'); }));
  await cache.get('a', async () => ({ok: true}));
  await cache.get('b', async () => ({ok: true}));
  assert.equal(cache.values.size, 1);
  assert.equal(cache.values.has('a'), false);
});
