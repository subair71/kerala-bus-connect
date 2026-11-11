import {initializeApp, applicationDefault} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {getAuth} from 'firebase-admin/auth';
const projectId = process.env.GOOGLE_CLOUD_PROJECT;
if (!projectId) throw new Error('Set GOOGLE_CLOUD_PROJECT explicitly.');
initializeApp({projectId, credential: applicationDefault()});
const db = getFirestore();
const initial = {
  basic: {name: 'Basic', pricePaise: 49900, durationDays: 30, radiusKm: 3, routeLimit: 0, adLimit: 1, coverage: ['nearby'], features: 'Nearby business placement'},
  standard: {name: 'Standard', pricePaise: 99900, durationDays: 30, radiusKm: 5, routeLimit: 5, adLimit: 3, coverage: ['nearby','route'], features: 'Nearby and route placements'},
  premium: {name: 'Premium', pricePaise: 199900, durationDays: 30, radiusKm: 20, routeLimit: 20, adLimit: 5, coverage: ['nearby','route','district'], features: 'Wider coverage and aggregated analytics'},
};
for (const [id, data] of Object.entries(initial)) await db.runTransaction(async tx => {
  const ref = db.doc('advertising_packages/' + id);
  if (!(await tx.get(ref)).exists) tx.create(ref, {...data, eligibleRouteIds: [], enabled: true});
});
await db.runTransaction(async tx => {
  const ref = db.doc('platform_config/commission');
  if (!(await tx.get(ref)).exists) tx.create(ref, {basisPoints: 3000});
});
// An administrator is never created from a client-submitted role.
if (process.env.FINDMYBUS_ADMIN_UID) {
  const user = await getAuth().getUser(process.env.FINDMYBUS_ADMIN_UID);
  await getAuth().setCustomUserClaims(user.uid, {...user.customClaims, admin: true});
  console.log('Administrator claim assigned. Sign out and back in to refresh the token.');
}
console.log('Initial configuration created where missing. Existing administrator values were preserved.');
