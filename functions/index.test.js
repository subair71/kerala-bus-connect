import test from 'node:test';
import assert from 'node:assert/strict';
import {placeSuggestions} from './index.js';

test('callable rejects unattested requests before reading a key or calling Google', async () => {
  await assert.rejects(placeSuggestions.run({data: {input: 'Aluva'}}),
    {code: 'unauthenticated', message: 'App verification required.'});
});
