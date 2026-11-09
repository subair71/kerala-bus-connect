// Run with Application Default Credentials only after deploying index triggers.
// This adds projections; it does not delete or migrate source collections.
import {initializeApp} from 'firebase-admin/app';
import {getFirestore, FieldPath} from 'firebase-admin/firestore';
import {indexSource} from './transit.js';
const projectId = process.env.GOOGLE_CLOUD_PROJECT;
if (!projectId) throw new Error('Set GOOGLE_CLOUD_PROJECT explicitly.');
initializeApp({projectId});
const db = getFirestore();
for (const collection of ['services', 'trip_adjustments']) {
  let cursor;
  let count = 0;
  while (true) {
    const base = db.collection(collection).orderBy(FieldPath.documentId());
    const page = await (cursor ? base.startAfter(cursor) : base).limit(50).get();
    for (const doc of page.docs) await indexSource(db, collection, doc.id);
    count += page.size;
    console.log(collection, count);
    if (page.size < 50) break;
    cursor = page.docs.at(-1);
  }
}
console.log('Backfill complete. Verify sample routes and index readiness before setting platform_config/search.ready=true.');
