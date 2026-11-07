import test from 'node:test';
import assert from 'node:assert/strict';
import {autocomplete, validateInput} from './places.js';

test('reject malformed, short, oversized and arbitrary proxy requests', () => {
  for (const data of [null, [], {}, {input: 0}, {input: 'al'}, {input: 'a'.repeat(121)},
    {input: 'Aluva', url: 'https://example.com'}, {input: 'Alu\nva'}]) {
    assert.throws(() => validateInput(data), {code: 'invalid-argument'});
  }
  assert.equal(validateInput({input: ' Aluva '}), 'Aluva');
  assert.equal(validateInput({input: 'തൃശൂർ'}), 'തൃശൂർ');
});

test('requests only autocomplete names and addresses with an India/Kerala bias', async () => {
  let request;
  const result = await autocomplete({input: 'Aluva'}, {
    apiKey: 'test-key',
    fetchImpl: async (url, options) => {
      request = {url, options};
      return {ok: true, json: async () => ({suggestions: [
        {placePrediction: {placeId: 'p1', structuredFormat: {
          mainText: {text: 'Aluva'}, secondaryText: {text: 'Kerala, India'},
        }}},
      ]})};
    },
  });
  assert.equal(request.url, 'https://places.googleapis.com/v1/places:autocomplete');
  assert.equal(request.options.method, 'POST');
  assert.equal(request.options.headers['X-Goog-Api-Key'], 'test-key');
  assert.ok(!request.options.headers['X-Goog-FieldMask'].includes('*'));
  assert.ok(request.options.signal instanceof AbortSignal);
  const body = JSON.parse(request.options.body);
  assert.deepEqual(body.includedRegionCodes, ['in']);
  assert.ok(body.locationBias.rectangle);
  assert.equal(body.sessionToken, undefined); // Autocomplete-only, per-request billing.
  assert.deepEqual(result, {suggestions: [{id: 'p1', name: 'Aluva', address: 'Kerala, India'}]});
});

test('empty and incomplete results are handled without invented places', async () => {
  const run = response => autocomplete({input: 'Aluva'}, {
    apiKey: 'test',
    fetchImpl: async () => ({ok: true, json: async () => response}),
  });
  assert.deepEqual(await run({}), {suggestions: []});
  assert.deepEqual(await run({suggestions: [{placePrediction: {}},
    {placePrediction: {placeId: 'p', structuredFormat: {mainText: {text: 'Aluva'}}}}]}),
    {suggestions: [{id: 'p', name: 'Aluva', address: ''}]});
  assert.equal((await run({suggestions: Array.from({length: 20}, (_, i) => ({
    placePrediction: {placeId: String(i), structuredFormat: {mainText: {text: 'Stop'}}},
  }))})).suggestions.length, 5);
});

test('upstream quota, permission, malformed and timeout errors are sanitized', async () => {
  for (const status of [403, 429, 500]) {
    await assert.rejects(autocomplete({input: 'Aluva'}, {
      apiKey: 'secret',
      fetchImpl: async () => ({ok: false, status}),
    }), {code: status === 429 ? 'resource-exhausted' : 'unavailable',
      message: 'Place suggestions are temporarily unavailable.'});
  }
  for (const json of [null, {unexpected: true}]) {
    await assert.rejects(autocomplete({input: 'Aluva'}, {
      apiKey: 'secret',
      fetchImpl: async () => ({ok: true, json: async () => json}),
    }), {code: 'unavailable'});
  }
  await assert.rejects(autocomplete({input: 'Aluva'}, {
    apiKey: 'secret', fetchImpl: async () => {throw new Error('secret');},
  }), {code: 'unavailable', message: 'Place suggestions are temporarily unavailable.'});
  await assert.rejects(autocomplete({input: 'Aluva'}, {apiKey: ''}), {code: 'failed-precondition'});
});
