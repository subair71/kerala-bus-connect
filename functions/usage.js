import {FieldValue, Timestamp} from 'firebase-admin/firestore';
import {HttpsError} from 'firebase-functions/v2/https';
import {hash} from './transit.js';

/// Opt-in installation metrics. No GPS, search text, contact details or auth IDs.
export async function recordEvent(db, data, now = Date.now()) {
  const events = ['session', 'search', 'search_failure', 'ad_impression', 'ad_click'];
  if (!events.includes(data?.event) || !/^[a-zA-Z0-9_-]{16,80}$/.test(data?.installationId ?? '') ||
      !/^[a-zA-Z0-9_-]{16,80}$/.test(data?.eventId ?? '')) throw new HttpsError('invalid-argument', 'Invalid event.');
  const day = new Date(now + 330 * 60000).toISOString().slice(0, 10);
  const month = day.slice(0, 7);
  const adId = typeof data.adId === 'string' && /^[a-zA-Z0-9_-]{1,128}$/.test(data.adId) ? data.adId : '';
  if (data.event.startsWith('ad_') && !adId) throw new HttpsError('invalid-argument', 'Advertisement required.');
  // Impression counted at most once per installation/ad/day, even across reloads.
  const key = hash(data.installationId + ':' + day + ':' +
    (data.event === 'ad_impression' ? data.event + ':' + adId : data.eventId));
  const eventRef = db.doc('usage_dedup/' + key);
  const dailyRef = db.doc('usage_dedup/' + hash('day:' + day + ':' + data.installationId));
  const monthlyRef = db.doc('usage_dedup/' + hash('month:' + month + ':' + data.installationId));
  const shard = parseInt(key.slice(0, 2), 16) % 32;
  return db.runTransaction(async tx => {
    const [event, daily, monthly] = await Promise.all([tx.get(eventRef), tx.get(dailyRef), tx.get(monthlyRef)]);
    if (event.exists) return {counted: false};
    if (adId) {
      const ad = (await tx.get(db.doc('sponsored_ads/' + adId))).data();
      if (!ad?.active || ad.approval !== 'approved' || ad.paidUntil <= now) return {counted: false};
    }
    const expiresAt = Timestamp.fromMillis(now + 40 * 86400000);
    tx.create(eventRef, {expiresAt});
    if (!daily.exists) tx.create(dailyRef, {expiresAt});
    if (!monthly.exists) tx.create(monthlyRef, {expiresAt});
    tx.set(db.doc('usage_daily/' + day + '_' + shard), {
      day, [data.event]: FieldValue.increment(1),
      measuredDailyUsers: FieldValue.increment(daily.exists ? 0 : 1),
    }, {merge: true});
    tx.set(db.doc('usage_monthly/' + month + '_' + shard), {
      month, measuredMonthlyUsers: FieldValue.increment(monthly.exists ? 0 : 1),
    }, {merge: true});
    if (adId) tx.set(db.doc('ad_metrics/' + adId + '_' + month + '_' + shard),
      {adId, month, [data.event]: FieldValue.increment(1)}, {merge: true});
    return {counted: true};
  });
}
