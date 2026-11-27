import { readFile } from 'node:fs/promises';
import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

const projectId = process.env.GOOGLE_CLOUD_PROJECT;
if (!projectId) throw new Error('Specify GOOGLE_CLOUD_PROJECT.');
const db = getFirestore(initializeApp({ projectId }));
const services = JSON.parse(await readFile(new URL('../assets/samples/services.json', import.meta.url), 'utf8'));
const fruits = [
  { id: 'mango', name: 'Mango' },
  { id: 'banana', name: 'Banana' },
  { id: 'pineapple', name: 'Pineapple' },
];
for (const [collection, rows] of [['sample_services', services], ['sample_fruits', fruits]]) {
  const refs = rows.map(row => db.collection(collection).doc(row.id));
  const created = await db.runTransaction(async tx => {
    const existing = await tx.getAll(...refs);
    let count = 0;
    for (const [i, snapshot] of existing.entries()) {
      if (snapshot.exists) continue;
      const { id, ...fields } = rows[i];
      tx.create(refs[i], { ...fields, sample: true });
      count++;
    }
    return count;
  });
  const saved = await db.getAll(...refs);
  if (!saved.every((doc, i) => doc.exists && doc.get('sample') === true &&
      (collection === 'sample_services' ? Array.isArray(doc.get('stops')) && doc.get('stops').length >= 2
        && typeof doc.get('departureMinutes') === 'number' : doc.get('name') === rows[i].name))) throw new Error('Sample verification failed for ' + collection);
  console.log(`Verified ${saved.length} in ${projectId}/${collection}. Created ${created}.`);
}
