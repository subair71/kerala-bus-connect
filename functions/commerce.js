import {analyticsDashboard} from './analytics.js';
import {FieldValue, FieldPath} from 'firebase-admin/firestore';
import {HttpsError} from 'firebase-functions/v2/https';
import {hash, validatePoint, cellFor, distanceKm, normalize} from './transit.js';

const fail = (message, code = 'invalid-argument') => { throw new HttpsError(code, message); };
export function text(value, name, max = 200) {
  if (typeof value !== 'string' || !value.trim() || value.length > max || /[\u0000-\u001f]/.test(value)) fail('Enter ' + name + '.');
  return value.trim();
}
export function integer(value, name, min, max) {
  if (!Number.isSafeInteger(value) || value < min || value > max) fail('Invalid ' + name + '.');
  return value;
}
const id = value => {
  const result = text(value, 'ID', 128);
  if (!/^[a-zA-Z0-9_-]+$/.test(result)) fail('Invalid ID.');
  return result;
};
const list = (value, name, max = 20) => {
  if (!Array.isArray(value) || value.length > max) fail('Invalid ' + name + '.');
  return [...new Set(value.map(id))];
};
const url = (value, required = false) => {
  if (!value && !required) return '';
  const result = text(value, 'HTTPS link', 2000);
  try { const parsed = new URL(result); if (parsed.protocol !== 'https:' || parsed.username || parsed.password) fail('Use an HTTPS link.'); }
  catch { fail('Use an HTTPS link.'); }
  return result;
};
export function commissionFor(amount, basisPoints) {
  integer(amount, 'amount in paise', 1, 100000000);
  integer(basisPoints, 'commission basis points', 0, 10000);
  return Math.floor((amount * basisPoints + 5000) / 10000);
}
export function packageData(data) {
  return {
    name: text(data.name, 'package name', 80),
    pricePaise: integer(data.pricePaise, 'price in paise', 1, 100000000),
    durationDays: integer(data.durationDays, 'duration', 1, 366),
    radiusKm: integer(data.radiusKm, 'radius', 1, 100),
    routeLimit: integer(data.routeLimit, 'route limit', 0, 20),
    adLimit: integer(data.adLimit, 'advertisement limit', 1, 100),
    coverage: listCoverage(data.coverage),
    eligibleRouteIds: list(data.eligibleRouteIds ?? [], 'eligible routes'),
    features: text(data.features || 'Local advertising', 'features', 1000),
    enabled: data.enabled !== false,
  };
}
function listCoverage(value) {
  if (!Array.isArray(value) || !value.length || value.some(v => !['nearby', 'route', 'district'].includes(v))) fail('Choose valid coverage.');
  return [...new Set(value)];
}
function authorized(auth) {
  if (!auth?.uid) fail('Sign in to continue.', 'unauthenticated');
  return {uid: auth.uid, admin: auth.token?.admin === true};
}
function owner(data, actor) {
  if (!data || data.ownerId !== actor.uid && !actor.admin) fail('You do not have access.', 'permission-denied');
}
function admin(actor) { if (!actor.admin) fail('Administrator access required.', 'permission-denied'); }
function financialStats(tx, db, ownerId, now, values) {
  const month = new Date(now + 330 * 60000).toISOString().slice(0, 7);
  for (const key of [ownerId, 'platform']) {
    tx.set(db.doc('owner_earnings/' + key), {ownerId: key,
      ...Object.fromEntries(Object.entries(values).map(([k, v]) => [k, FieldValue.increment(v)]))}, {merge: true});
    tx.set(db.doc('financial_stats/' + key + '_' + month),
      {ownerId: key, month, ...Object.fromEntries(Object.entries(values).map(([k, v]) => [k, FieldValue.increment(v)]))},
      {merge: true});
  }
}
function eligible(ad, now) {
  return ad.approval === 'approved' && !ad.cancelled &&
    (ad.paidPeriods ?? []).some(p => !p.refunded && p.start <= now && p.end > now);
}
export async function platformAction(db, auth, input, now = Date.now()) {
  const actor = authorized(auth);
  const action = text(input?.action, 'action', 80);
  const data = input?.data ?? {};
  const requestId = id(input?.requestId);
  const operation = db.doc('platform_operations/' + hash(actor.uid + ':' + requestId));
  const fingerprint = hash(JSON.stringify({action, data}));
  return db.runTransaction(async tx => {
    const previous = await tx.get(operation);
    if (previous.exists) {
      if (previous.data().fingerprint !== fingerprint) fail('This request ID was used for a different action.');
      return previous.data().result;
    }
    const access = await tx.get(db.doc('owner_access/' + actor.uid));
    if (access.data()?.disabled && !actor.admin) fail('Account suspended. Contact support.', 'permission-denied');
    let result = {ok: true};
    const deterministicId = hash(actor.uid + ':' + requestId);
    if (action === 'savePackage') {
      admin(actor);
      const packageId = id(data.id);
      tx.set(db.doc('advertising_packages/' + packageId), packageData(data));
      result.id = packageId;
    } else if (action === 'configureCommission') {
      admin(actor);
      tx.set(db.doc('platform_config/commission'), {basisPoints: integer(data.basisPoints, 'commission percentage', 0, 10000)});
    } else if (action === 'registerAdvertiser') {
      const target = db.doc('advertisers/' + deterministicId);
      tx.create(target, {
        ownerId: actor.uid, name: text(data.name, 'business name', 120),
        category: text(data.category, 'business category', 80),
        contact: text(data.contact, 'contact details', 200),
        location: validatePoint(data), district: normalize(text(data.district, 'district', 80)),
        activeAds: 0, createdAt: now,
      });
      result.id = target.id;
    } else if (action === 'updateAdvertiser') {
      const target = db.doc('advertisers/' + id(data.id));
      const current = (await tx.get(target)).data(); owner(current, actor);
      tx.update(target, {name: text(data.name, 'business name', 120),
        category: text(data.category, 'business category', 80),
        contact: text(data.contact, 'contact details', 200),
        location: validatePoint(data), district: normalize(text(data.district, 'district', 80)),
        updatedAt: now});
      result.id = target.id;
    } else if (action === 'submitAd') {
      const advertiser = (await tx.get(db.doc('advertisers/' + id(data.advertiserId)))).data();
      owner(advertiser, actor);
      const target = db.doc('sponsored_ads/' + (data.id ? id(data.id) : deterministicId));
      const existing = (await tx.get(target)).data();
      if (existing) owner(existing, actor);
      if (existing && existing.advertiserId !== data.advertiserId) fail('Keep the original advertiser.');
      if (existing && existing.packageId !== data.packageId && (existing.paidUntil > now || existing.pendingOrderId)) fail('Finish the paid period and pending order before changing packages.');
      const pack = (await tx.get(db.doc('advertising_packages/' + id(data.packageId)))).data();
      if (!pack?.enabled) fail('Choose an available package.');
      const routes = list(data.routeIds ?? [], 'routes');
      const stops = list(data.stopIds ?? [], 'stops');
      const coverage = text(data.coverage, 'coverage', 20);
      if (!pack.coverage.includes(coverage) || routes.length > pack.routeLimit ||
          (pack.eligibleRouteIds?.length && routes.some(r => !pack.eligibleRouteIds.includes(r)))) fail('Coverage exceeds the package.');
      if (coverage === 'route' && !routes.length && !stops.length) fail('Select routes or stops.');
      const radiusKm = integer(data.radiusKm, 'radius', 1, pack.radiusKm);
      const existingAds = await tx.get(db.collection('sponsored_ads').where('advertiserId', '==', data.advertiserId).limit(101));
      if (!existing && existingAds.size >= pack.adLimit) fail('Advertisement limit reached for this advertiser.');
      const point = validatePoint(data);
      const ad = {
        ...(existing ?? {}), ownerId: advertiser.ownerId,
        advertiserId: data.advertiserId, advertiser: advertiser.name, category: advertiser.category,
        title: text(data.title, 'advertisement title', 120),
        description: text(data.description, 'description', 1000),
        imageUrl: url(data.imageUrl, true), website: url(data.website),
        location: text(data.location, 'location name', 120),
        district: normalize(text(data.district, 'district', 80)), ...point,
        routeIds: routes, stopIds: stops, coverage, radiusKm, coverageCells: coverageCells(point, radiusKm), packageId: data.packageId,
        requestedStart: data.requestedStart ? Date.parse(data.requestedStart) : now,
        approval: 'pending', active: false, cancelled: existing?.cancelled ?? false,
        createdAt: existing?.createdAt ?? now, updatedAt: now,
        paidPeriods: existing?.paidPeriods ?? [], paidUntil: existing?.paidUntil ?? 0,
      };
      if (!Number.isFinite(ad.requestedStart) || ad.requestedStart > now + 366 * 86400000) fail('Choose a start date within one year.');
      writeAd(tx, db, target, existing, ad, now); result.id = target.id;
    } else if (action === 'createOrder') {
      const adRef = db.doc('sponsored_ads/' + id(data.adId));
      const ad = (await tx.get(adRef)).data(); owner(ad, actor);
      const advertiser = (await tx.get(db.doc('advertisers/' + ad.advertiserId))).data();
      if (!advertiser) fail('Advertiser is unavailable.');
      const pack = (await tx.get(db.doc('advertising_packages/' + ad.packageId))).data();
      const config = (await tx.get(db.doc('platform_config/commission'))).data();
      if (!pack?.enabled || !config) fail('Advertising configuration is unavailable.', 'failed-precondition');
      if (!['ownerCollected', 'direct'].includes(data.workflow)) fail('Choose a payment workflow.');
      if (ad.cancelled) fail('An administrator must reinstate this advertisement before renewal.');
      if (ad.pendingOrderId) {
        const pending = (await tx.get(db.doc('advertising_orders/' + ad.pendingOrderId))).data();
        if (pending && ['pending', 'submitted'].includes(pending.status)) {
          if (pending.ownerId !== actor.uid && !actor.admin) fail('An administrator must resolve the former owner’s pending order.');
          result = {ok: true, id: ad.pendingOrderId};
        }
      }
      if (!result.id) {
        if ((ad.paidPeriods?.length ?? 0) >= 120) fail('Contact an administrator to archive older paid periods.');
        const orderId = deterministicId;
        const commission = commissionFor(pack.pricePaise, config.basisPoints);
        tx.create(db.doc('advertising_orders/' + orderId), {
          ownerId: advertiser.ownerId, advertiserId: ad.advertiserId, adId: data.adId,
          packageId: ad.packageId, packageSnapshot: pack,
          pricePaise: pack.pricePaise, commissionBasisPoints: config.basisPoints,
          commissionPaise: commission, platformSharePaise: pack.pricePaise - commission,
          duePaise: data.workflow === 'ownerCollected' ? pack.pricePaise - commission : pack.pricePaise,
          workflow: data.workflow, status: 'pending', createdAt: now,
          renewal: (ad.paidPeriods?.length ?? 0) > 0,
        });
        writeAd(tx, db, adRef, ad, {pendingOrderId: orderId}, now);
        result.id = orderId;
      }
    } else if (action === 'submitReceipt') {
      const target = db.doc('advertising_orders/' + id(data.orderId));
      const order = (await tx.get(target)).data(); owner(order, actor);
      if (!['pending', 'submitted'].includes(order.status)) fail('This order can no longer accept a receipt.');
      tx.update(target, {receipt: text(data.receipt, 'receipt/reference', 1000), status: 'submitted', submittedAt: now});
    } else if (action === 'verifyPayment') {
      admin(actor);
      const target = db.doc('advertising_orders/' + id(data.orderId));
      const order = (await tx.get(target)).data();
      if (!order) fail('Order not found.', 'not-found');
      if (order.status === 'paid') return {ok: true, id: target.id};
      if (order.status !== 'submitted' || !order.receipt) fail('A submitted receipt is required.');
      if (integer(data.receivedPaise, 'received amount', 0, 100000000) !== order.duePaise) fail('The verified amount must match the platform amount due.');
      const reference = text(data.transactionReference, 'verified transaction reference', 200);
      const receiptRef = db.doc('verified_payments/' + hash(normalize(reference)));
      if ((await tx.get(receiptRef)).exists) fail('This payment has already been used.');
      const adRef = db.doc('sponsored_ads/' + order.adId);
      const ad = (await tx.get(adRef)).data();
      if (!ad || ad.cancelled || ad.pendingOrderId !== target.id) fail('This advertisement cannot be renewed.');
      const commissionRef = db.doc('commissions/' + target.id);
      if ((await tx.get(commissionRef)).exists) fail('Commission already exists.', 'already-exists');
      const start = Math.max(now, ad.paidUntil ?? 0, ad.requestedStart ?? 0);
      const end = start + order.packageSnapshot.durationDays * 86400000;
      const periods = [...(ad.paidPeriods ?? []), {orderId: target.id, start, end, refunded: false}];
      tx.update(target, {status: 'paid', verifiedBy: actor.uid, verifiedAt: now, transactionReference: reference,
        periodStart: start, periodEnd: end});
      tx.create(receiptRef, {orderId: target.id, reference, verifiedBy: actor.uid, receivedPaise: order.duePaise, at: now});
      tx.create(commissionRef, {ownerId: order.ownerId, advertiserId: order.advertiserId, adId: order.adId,
        orderId: target.id, amountPaise: order.commissionPaise, basisPoints: order.commissionBasisPoints,
        paymentPaise: order.pricePaise, renewalDate: now,
        status: order.workflow === 'ownerCollected' ? 'retained' : 'payable', createdAt: now});
      writeAd(tx, db, adRef, ad, {paidPeriods: periods, paidUntil: end, pendingOrderId: null}, now);
      financialStats(tx, db, order.ownerId, now, {revenuePaise: order.pricePaise,
        platformSharePaise: order.platformSharePaise, earnedPaise: order.commissionPaise,
        [order.workflow === 'ownerCollected' ? 'retainedPaise' : 'pendingPaise']: order.commissionPaise,
        paidOrders: 1, renewals: order.renewal ? 1 : 0});
    } else if (action === 'reviewAd') {
      admin(actor);
      const target = db.doc('sponsored_ads/' + id(data.adId));
      const ad = (await tx.get(target)).data();
      if (!ad) fail('Advertisement not found.', 'not-found');
      if (!['approved', 'rejected'].includes(data.approval)) fail('Choose approve or reject.');
      const update = {approval: data.approval, reviewNote: text(data.note, 'review note', 1000), reviewedBy: actor.uid, reviewedAt: now};
      writeAd(tx, db, target, ad, update, now);
    } else if (action === 'cancelAd') {
      admin(actor);
      const target = db.doc('sponsored_ads/' + id(data.adId));
      const ad = (await tx.get(target)).data();
      if (!ad) fail('Advertisement not found.', 'not-found');
      const cancelled = data.cancelled !== false;
      writeAd(tx, db, target, ad, {cancelled, cancellationNote: text(data.note, 'reason', 1000)}, now);
    } else if (action === 'cancelOrder') {
      const target = db.doc('advertising_orders/' + id(data.orderId));
      const order = (await tx.get(target)).data(); owner(order, actor);
      if (!['pending', 'submitted'].includes(order.status)) fail('Use the refund workflow for a paid order.');
      const adRef = db.doc('sponsored_ads/' + order.adId);
      const ad = (await tx.get(adRef)).data();
      tx.update(target, {status: 'cancelled', cancelledAt: now});
      if (ad?.pendingOrderId === target.id) tx.update(adRef, {pendingOrderId: null});
    } else if (action === 'refundOrder') {
      admin(actor);
      const target = db.doc('advertising_orders/' + id(data.orderId));
      const order = (await tx.get(target)).data();
      if (!order || order.status !== 'paid') fail('Choose a paid order.');
      const commissionRef = db.doc('commissions/' + target.id);
      const commission = (await tx.get(commissionRef)).data();
      const adRef = db.doc('sponsored_ads/' + order.adId);
      const ad = (await tx.get(adRef)).data();
      if (!ad || !commission) fail('Financial records are incomplete.', 'failed-precondition');
      const periods = ad.paidPeriods.map(p => p.orderId === target.id ? {...p, refunded: true} : p);
      tx.update(target, {status: 'refunded', refundReference: text(data.reference, 'completed refund reference', 200),
        refundedAt: now, refundedBy: actor.uid});
      tx.update(commissionRef, {status: commission.status === 'payable' ? 'reversed' : 'recoveryDue',
        recoveryDuePaise: commission.status === 'payable' ? 0 : commission.amountPaise, reversedAt: now});
      writeAd(tx, db, adRef, ad, {paidPeriods: periods,
        paidUntil: Math.max(0, ...periods.filter(p => !p.refunded).map(p => p.end))}, now);
      financialStats(tx, db, order.ownerId, now, {refundPaise: order.pricePaise, earnedPaise: -order.commissionPaise,
        ...(commission.status === 'payable' ? {pendingPaise: -order.commissionPaise} : {recoveryDuePaise: order.commissionPaise})});
    } else if (action === 'recordPayout') {
      admin(actor);
      const ids = list(data.commissionIds, 'commissions', 50);
      if (!ids.length) fail('Choose payable commissions.');
      const docs = await Promise.all(ids.map(value => tx.get(db.doc('commissions/' + value))));
      const commissions = docs.map(d => d.data());
      if (commissions.some(v => !v || v.status !== 'payable') ||
          commissions.some(v => v.ownerId !== commissions[0].ownerId)) fail('Choose unpaid commissions belonging to one owner.');
      const amount = commissions.reduce((sum, v) => sum + v.amountPaise, 0);
      if (data.amountPaise !== amount) fail('Payout amount does not match commissions.');
      const reference = text(data.reference, 'completed payout reference', 200);
      const payoutRef = db.doc('payouts/' + hash(normalize(reference)));
      if ((await tx.get(payoutRef)).exists) fail('Payout reference already exists.');
      tx.create(payoutRef, {ownerId: commissions[0].ownerId, amountPaise: amount,
        commissionIds: ids, reference, status: 'paid', paidAt: now, verifiedBy: actor.uid});
      docs.forEach(doc => tx.update(doc.ref, {status: 'paid', payoutId: payoutRef.id}));
      financialStats(tx, db, commissions[0].ownerId, now, {pendingPaise: -amount, paidPaise: amount});
    } else if (action === 'changeAttribution') {
      admin(actor);
      const target = db.doc('advertisers/' + id(data.advertiserId));
      if (!(await tx.get(target)).exists) fail('Advertiser not found.');
      const related = await tx.get(db.collection('sponsored_ads').where('advertiserId', '==', data.advertiserId).limit(101));
      if (related.size > 100) fail('Archive older advertisements before changing attribution.');
      for (const ad of related.docs) tx.update(ad.ref, {ownerId: id(data.ownerId)});
      tx.update(target, {ownerId: id(data.ownerId), attributionReason: text(data.note, 'reason', 1000)});
    } else if (action === 'saveStop') {
      admin(actor);
      const point = validatePoint(data);
      tx.set(db.doc('stops/' + id(data.id)), {...point, cell: cellFor(point),
        name: text(data.name, 'stop name', 120), nameLower: normalize(data.name), district: normalize(text(data.district, 'district', 80)),
        routeIds: list(data.routeIds ?? [], 'routes'), active: data.active !== false, verifiedBy: actor.uid});
    } else if (action === 'ownerAccess') {
      admin(actor);
      tx.set(db.doc('owner_access/' + id(data.ownerId)), {disabled: data.disabled === true, note: text(data.note, 'reason', 1000)});
    } else if (action === 'reportSchedule') {
      const tripId = id(data.tripId);
      if (!(await tx.get(db.doc('services/' + tripId))).exists) fail('Trip not found.');
      tx.create(db.doc('schedule_reports/' + deterministicId), {ownerId: actor.uid, tripId,
        message: text(data.message, 'incorrect timing details', 1000), status: 'pending', createdAt: now});
    } else if (action === 'reviewSchedule' || action === 'reviewReport') {
      admin(actor);
      const collection = action === 'reviewSchedule' ? 'services' : 'schedule_reports';
      const target = db.doc(collection + '/' + id(data.id));
      const reviewed = await tx.get(target);
      if (!reviewed.exists) fail('Record not found.');
      tx.update(target, {reviewedRevision: reviewed.data().scheduleRevision ?? '', verification: text(data.verification, 'verification result', 80),
        reviewNote: text(data.note, 'review note', 1000), reviewedBy: actor.uid, reviewedAt: now});
    } else fail('Unknown action.');
    tx.create(db.doc('platform_audit/' + deterministicId), {actorId: actor.uid, action,
      targetId: result.id ?? data.adId ?? data.orderId ?? data.id ?? '', at: now,
      requestHash: fingerprint});
    tx.create(operation, {fingerprint, result, at: now});
    return result;
  });
}
const allowedLists = new Set(['advertisers', 'sponsored_ads', 'advertising_orders', 'commissions', 'payouts',
  'advertising_packages', 'financial_stats', 'owner_earnings', 'schedule_reports', 'platform_notifications', 'businesses', 'services', 'routes', 'stops', 'owner_access']);
export async function platformList(db, auth, data) {
  const actor = authorized(auth);
  const collection = text(data?.collection, 'collection', 80);
  if (collection === 'analytics') { admin(actor); return analyticsDashboard(db); }
  if (!allowedLists.has(collection)) fail('Unknown list.');
  if (['owner_access', 'services', 'businesses'].includes(collection)) admin(actor);
  let query = db.collection(collection);
  if (!actor.admin && !['advertising_packages', 'stops', 'routes'].includes(collection)) query = query.where('ownerId', '==', actor.uid);
  query = query.orderBy(FieldPath.documentId()).limit(21);
  if (data.cursor) query = query.startAfter(id(data.cursor));
  const result = await query.get();
  const docs = result.docs.slice(0, 20);
  return {records: docs.map(d => ({id: d.id, ...d.data()})), cursor: result.size > 20 ? docs.at(-1).id : null};
}
export function adMatches(ad, context, now = Date.now()) {
  if (!eligible(ad, now)) return false;
  if (ad.coverage === 'district') return (context.districts ?? [context.district]).some(region => region && normalize(ad.district) === normalize(region));
  if (ad.coverage === 'route') return ad.routeIds.some(r => context.routeIds?.includes(r)) ||
    ad.stopIds.some(s => context.stopIds?.includes(s));
  return (context.points ?? []).some(point => distanceKm(point, ad) <= ad.radiusKm);
}
export async function targetedAds(db, data, now = Date.now()) {
  const routeIds = list(data?.routeIds ?? [], 'routes');
  const stopIds = list(data?.stopIds ?? [], 'stops');
  // Coordinates come from verified stop records, never an untrusted district claim.
  const stops = await Promise.all(stopIds.map(value => db.doc('stops/' + value).get()));
  for (const label of [data?.from, data?.to].filter(v => typeof v === 'string' && v.length <= 120 && v.trim())) {
    const matches = await db.collection('stops').where('nameLower', '==', normalize(label)).where('active', '==', true).limit(5).get();
    for (const stop of matches.docs) { stops.push(stop); if (!stopIds.includes(stop.id)) stopIds.push(stop.id); }
  }
  const points = stops.filter(s => s.exists && s.data().active).map(s => s.data());
  const districts = [...new Set(points.map(p => p.district))];
  const queries = [];
  const cells = [...new Set(points.map(cellFor))];
  if (cells.length) queries.push(db.collection('sponsored_ads').where('active', '==', true).where('coverageCells', 'array-contains-any', cells));
  if (routeIds.length) queries.push(db.collection('sponsored_ads').where('active', '==', true).where('routeIds', 'array-contains-any', routeIds));
  if (stopIds.length) queries.push(db.collection('sponsored_ads').where('active', '==', true).where('stopIds', 'array-contains-any', stopIds));
  // Geographic candidates include district boundaries; district-wide coverage is queried separately.
  for (const region of new Set(points.map(p => p.district))) queries.push(db.collection('sponsored_ads').where('active', '==', true).where('district', '==', region));
  const matches = new Map();
  for (const query of queries) {
    const result = await query.orderBy(FieldPath.documentId()).limit(50).get();
    for (const doc of result.docs) if (adMatches(doc.data(), {routeIds, stopIds, points, districts}, now)) matches.set(doc.id, doc.data());
  }
  return {ads: [...matches].slice(0, 5).map(([id, ad]) => ({id, advertiser: ad.advertiser,
    title: ad.title, description: ad.description, imageUrl: ad.imageUrl, website: ad.website,
    location: ad.location, active: true, expiresAt: Math.min(...ad.paidPeriods.filter(p => !p.refunded && p.start <= now && p.end > now).map(p => p.end))}))};
}

function coverageCells(point, radiusKm) {
  const x = Math.floor(point.latitude * 20), y = Math.floor(point.longitude * 20);
  const reach = Math.ceil(radiusKm / 5.4) + 1;
  const cells = [];
  for (let dx = -reach; dx <= reach; dx++) for (let dy = -reach; dy <= reach; dy++) cells.push((x + dx) + ':' + (y + dy));
  return cells;
}

export function nextAdTransition(ad, now) {
  if (ad.cancelled || ad.approval !== 'approved') return Number.MAX_SAFE_INTEGER;
  const boundaries = (ad.paidPeriods ?? []).filter(p => !p.refunded)
    .flatMap(p => [p.start, p.end - 7 * 86400000, p.end]).filter(at => at > now);
  return boundaries.length ? Math.min(...boundaries) : Number.MAX_SAFE_INTEGER;
}
export function writeAd(tx, db, reference, previous, patch, now) {
  const next = {...previous, ...patch};
  next.active = eligible(next, now);
  next.nextTransitionAt = nextAdTransition(next, now);
  const delta = Number(next.active) - Number(previous?.active === true);
  if (delta) tx.set(db.doc('advertisers/' + next.advertiserId),
    {activeAds: FieldValue.increment(delta)}, {merge: true});
  tx.set(reference, next);
}
