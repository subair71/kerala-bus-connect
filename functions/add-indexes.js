// Add missing composite indexes without deleting any production indexes.
// GOOGLE_CLOUD_PROJECT must identify the reviewed Firebase project.
import {readFile} from 'node:fs/promises';
import {applicationDefault} from 'firebase-admin/app';
const project = process.env.GOOGLE_CLOUD_PROJECT;
if (!/^[a-z][a-z0-9-]+$/.test(project ?? '')) throw new Error('Set GOOGLE_CLOUD_PROJECT explicitly.');
const credential = applicationDefault();
const configuration = JSON.parse(await readFile(new URL('../firestore.indexes.json', import.meta.url), 'utf8'));
const canonical = fields => JSON.stringify(fields.filter(f => f.fieldPath !== '__name__').map(f =>
  [f.fieldPath, f.order ?? f.arrayConfig]));
async function request(path, method = 'GET', body) {
  const {access_token} = await credential.getAccessToken();
  const response = await fetch('https://firestore.googleapis.com/v1/' + path, {
    method, headers: {Authorization: 'Bearer ' + access_token, 'Content-Type': 'application/json'},
    body: body ? JSON.stringify(body) : undefined,
  });
  if (!response.ok) throw new Error('Index API returned ' + response.status + ' for ' + method + ' ' + path);
  return response.json();
}
let pending = false;
for (const index of configuration.indexes) {
  const parent = 'projects/' + project + '/databases/(default)/collectionGroups/' + index.collectionGroup;
  let pageToken, existing = [];
  do {
    const page = await request(parent + '/indexes' + (pageToken ? '?pageToken=' + encodeURIComponent(pageToken) : ''));
    existing.push(...(page.indexes ?? [])); pageToken = page.nextPageToken;
  } while (pageToken);
  const match = existing.find(i => i.queryScope === index.queryScope && canonical(i.fields) === canonical(index.fields));
  if (match) {
    console.log(index.collectionGroup, match.state);
    if (match.state !== 'READY') pending = true;
  } else {
    await request(parent + '/indexes', 'POST', {queryScope: index.queryScope, fields: index.fields});
    console.log(index.collectionGroup, 'CREATED; wait for READY');
    pending = true;
  }
}
console.log(pending ? 'Some indexes are building. Run this command again before rollout.' : 'All required composite indexes are READY.');
// TTL and exemptions are listed separately in the deployment guide for review.
