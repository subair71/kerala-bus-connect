import {SearchCache} from './search-cache.js';
const caches = new WeakMap();
function cacheFor(db) {
  if (!caches.has(db)) caches.set(db, new SearchCache());
  return caches.get(db);
}
import {createHash} from 'node:crypto';
import {FieldPath} from 'firebase-admin/firestore';
import {HttpsError} from 'firebase-functions/v2/https';

export const normalize = value => String(value ?? '').trim().toLowerCase();
export const hash = value => createHash('sha256').update(value).digest('hex');
export const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
export function dateKey(value) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value) ||
      new Date(value + 'T00:00:00Z').toISOString().slice(0, 10) !== value) {
    throw new HttpsError('invalid-argument', 'Choose a valid date.');
  }
  return value;
}
export function shiftDate(value, offset) {
  const date = new Date(dateKey(value) + 'T00:00:00Z');
  date.setUTCDate(date.getUTCDate() + offset);
  return date.toISOString().slice(0, 10);
}
export function tokens(value) {
  const chars = [...normalize(value)];
  const result = new Set(['']);
  for (let length = 1; length <= 3; length++) {
    for (let i = 0; i <= chars.length - length; i++) result.add(chars.slice(i, i + length).join(''));
  }
  return [...result];
}
export function publicService(id, data) {
  const fields = ['ownerId', 'businessId', 'busId', 'routeId', 'businessName', 'routeName',
    'busName', 'stops', 'stopIds', 'departureMinutes', 'stopTimings', 'offDays',
    'offTimingsNote', 'published', 'scheduleRevision', 'arrivalStopTimings'];
  return {id, ...Object.fromEntries(fields.filter(k => data[k] !== undefined).map(k => [k, data[k]]))};
}
export function scheduleFingerprint(service) {
  return hash(JSON.stringify([service.stops, service.stopTimings, service.departureMinutes,
    service.offDays, service.published, service.scheduleRevision]));
}
export function projectDepartures(tripId, service, adjustment = null) {
  if (!service?.published || !Array.isArray(service.stops) || service.stops.length > 100) return [];
  if (adjustment && adjustment.scheduleRevision !== service.scheduleRevision) return [];
  const offDays = Array.isArray(service.offDays) ? service.offDays : days;
  const records = [];
  const validStatus = ['scheduled', 'onTime', 'delayed', 'cancelled', 'completed'];
  const status = validStatus.includes(adjustment?.status) ? adjustment.status :
    adjustment && Object.values(adjustment.delays ?? {}).some(n => n > 0) ? 'delayed' : 'scheduled';
  let delay = 0;
  for (let i = 0; i < service.stops.length; i++) {
    const stop = service.stops[i];
    const scheduled = service.stopTimings?.[stop] ?? (i === 0 ? service.departureMinutes : null);
    if (!Number.isInteger(scheduled) || scheduled < 0 || scheduled > 2879) continue;
    const additional = adjustment?.delays?.[service.stopIds?.[i]] ?? 0;
    if (!Number.isInteger(additional) || additional < 0 || additional > 1440) return [];
    delay += additional;
    const minutes = scheduled + (status === 'delayed' ? delay : 0);
    const dayOffset = Math.floor(minutes / 1440);
    const scope = adjustment ? shiftDate(adjustment.serviceDate, dayOffset) : 'recurring';
    const boardingDays = days.filter((_, d) => !offDays.includes(days[((d - dayOffset) % 7 + 7) % 7]));
    const keys = [];
    for (const day of ['*', ...boardingDays]) {
      for (const token of tokens(stop)) keys.push(day + '|stop|' + token);
      if (i === 0) keys.push(day + '|origin');
    }
    if (i === 0) {
      for (const token of new Set([service.routeName, ...service.stops].flatMap(tokens))) {
        keys.push('*|directory|' + token);
      }
    }
    records.push({
      tripId, stopIndex: i, stopName: stop, minute: minutes % 1440, dayOffset,
      scope, keys, status, serviceDate: adjustment?.serviceDate ?? null,
      revision: scheduleFingerprint(service),
      service: {stops: service.stops, routeName: service.routeName ?? ''},
      expectedStopTimings: adjustment ? Object.fromEntries(service.stops.map((name, n) => [
        name, service.stopTimings?.[name] + (status === 'delayed' ?
          service.stops.slice(0, n + 1).reduce((sum, _, j) => sum + (adjustment.delays?.[service.stopIds?.[j]] ?? 0), 0) : 0),
      ]).filter(([, value]) => Number.isFinite(value))) : {},
    });
  }
  return records;
}

/// Read the current source inside a transaction, so retries/out-of-order events
/// cannot resurrect an older schedule or a deleted daily adjustment.
export async function indexSource(db, collection, id) {
  const sourceKey = collection + ':' + id;
  const marker = db.collection('departure_projections').doc(hash(sourceKey));
  await db.runTransaction(async tx => {
    const source = await tx.get(db.collection(collection).doc(id));
    const data = source.data();
    const prior = await tx.get(marker);
    const tripId = collection === 'services' ? id : data?.tripId ?? prior.data()?.tripId;
    const service = collection === 'services' ? source :
      tripId ? await tx.get(db.collection('services').doc(tripId)) : null;
    const rows = data && service?.exists ? projectDepartures(tripId, service.data(),
      collection === 'services' ? null : data) : [];
    const digest = hash(JSON.stringify(rows));
    if (prior.data()?.digest === digest) return;
    const old = await tx.get(db.collection('stop_departures').where('sourceKey', '==', sourceKey));
    for (const doc of old.docs) tx.delete(doc.ref);
    for (const row of rows) {
      tx.set(db.collection('stop_departures').doc(hash(sourceKey + ':' + row.stopIndex)), {...row, sourceKey});
    }
    tx.set(marker, {digest, tripId: tripId ?? '', version: 1});
  });
  cacheFor(db).clear();
}
export function rowMatches(row, input) {
  const names = row.service.stops.map(normalize);
  if (input.directory) return row.stopIndex === 0 &&
    (!input.from || normalize(row.service.routeName).includes(input.from) || names.some(s => s.includes(input.from)));
  const origin = input.from ? names.findIndex(s => s.includes(input.from)) : 0;
  const destination = input.to ? names.findIndex(s => s.includes(input.to)) : names.length - 1;
  return row.stopIndex === origin && origin >= 0 && destination >= 0 &&
    (!input.to || origin < destination);
}
export function searchDepartures(db, raw, now = new Date()) {
  const key = JSON.stringify([raw, Math.floor(now.getTime() / 60000)]);
  return cacheFor(db).get(key, () => queryDepartures(db, raw, now));
}
export async function queryDepartures(db, raw, now = new Date()) {
  const ready = await db.doc('platform_config/search').get();
  if (ready.data()?.ready !== true) throw new HttpsError('failed-precondition', 'Search index is not ready.');
  const input = {
    from: normalize(raw?.from), to: normalize(raw?.to),
    date: dateKey(raw?.date), directory: raw?.directory === true,
  };
  if (input.from.length > 120 || input.to.length > 120) throw new HttpsError('invalid-argument', 'Search text is too long.');
  const binding = hash(JSON.stringify(input));
  const cursor = raw?.cursor;
  if (cursor && (cursor.binding !== binding || !Array.isArray(cursor.positions) || cursor.positions.length !== 2)) {
    throw new HttpsError('invalid-argument', 'Restart this search.');
  }
  const today = new Date(now.getTime() + 330 * 60000).toISOString().slice(0, 10);
  const currentMinute = (now.getUTCHours() * 60 + now.getUTCMinutes() + 330) % 1440;
  const minimum = input.directory || input.date !== today ? 0 : currentMinute;
  const day = days[new Date(input.date + 'T00:00:00Z').getUTCDay()];
  const token = [...input.from].slice(0, 3).join('');
  const key = input.directory ? '*|directory|' + token :
    input.from ? day + '|stop|' + token : day + '|origin';
  const positions = cursor?.positions?.map(p => p ? [...p] : null) ?? [null, null];
  const exhausted = cursor?.exhausted ? [...cursor.exhausted] : [false, input.directory];
  const buffers = [[], []];
  const collections = ['recurring', input.date];
  const rows = [];
  let scanned = 0;
  const memo = new Map();
  async function read(path) {
    if (!memo.has(path)) memo.set(path, db.doc(path).get());
    return memo.get(path);
  }
  async function fill(i) {
    if (buffers[i].length || exhausted[i]) return;
    let query = db.collection('stop_departures').where('scope', '==', collections[i])
      .where('keys', 'array-contains', key).where('minute', '>=', minimum)
      .orderBy('minute').orderBy(FieldPath.documentId()).limit(12);
    if (positions[i]) {
      if (!Array.isArray(positions[i]) || !Number.isInteger(positions[i][0]) || !/^[a-f0-9]{64}$/.test(positions[i][1])) {
        throw new HttpsError('invalid-argument', 'Restart this search.');
      }
      query = query.startAfter(...positions[i]);
    }
    const page = await query.get();
    buffers[i] = page.docs;
    if (!page.size) exhausted[i] = true;
  }
  while (rows.length < 4 && scanned < 120) {
    await Promise.all([fill(0), fill(1)]);
    const a = buffers[0][0], b = buffers[1][0];
    if (!a && !b) break;
    const i = !a ? 1 : !b ? 0 :
      a.data().minute < b.data().minute ||
      a.data().minute === b.data().minute && a.id < b.id ? 0 : 1;
    const doc = buffers[i].shift();
    const row = doc.data();
    positions[i] = [row.minute, doc.id];
    scanned++;
    if (!rowMatches(row, input)) continue;
    if (!memo.has('services/' + row.tripId)) {
      const candidates = [row, ...buffers.flat().map(d => d.data())]
        .filter(candidate => rowMatches(candidate, input))
        .sort((a, b) => a.minute - b.minute).slice(0, 4);
      const paths = new Set();
      for (const candidate of candidates) {
        paths.add('services/' + candidate.tripId);
        paths.add('trip_adjustments/' + candidate.tripId + '_' +
          (candidate.serviceDate ?? shiftDate(input.date, -candidate.dayOffset)));
      }
      const missing = [...paths].filter(path => !memo.has(path));
      if (missing.length) {
        const snapshots = await db.getAll(...missing.map(path => db.doc(path)));
        snapshots.forEach((snapshot, index) => memo.set(missing[index], Promise.resolve(snapshot)));
      }
    }
    const service = (await read('services/' + row.tripId)).data();
    if (!service?.published || scheduleFingerprint(service) !== row.revision) continue;
    const startDate = row.serviceDate ?? shiftDate(input.date, -row.dayOffset);
    const adjustment = (await read('trip_adjustments/' + row.tripId + '_' + startDate)).data();
    const validDaily = adjustment && adjustment.scheduleRevision === service.scheduleRevision;
    if (!input.directory && (i === 0 && validDaily || i === 1 && !validDaily)) continue;
    if (i === 1) {
      const current = projectDepartures(row.tripId, service, adjustment).find(r => r.stopIndex === row.stopIndex);
      if (!current || current.scope !== row.scope || current.minute !== row.minute || current.status !== row.status) continue;
    }
    rows.push({...publicService(row.tripId, service), runningStatus: row.status,
      serviceDate: startDate, expectedStopTimings: row.expectedStopTimings,
      boardingMinute: row.minute});
  }
  const hasMore = buffers.some(b => b.length > 0) || exhausted.some(v => !v);
  return {records: rows, cursor: hasMore ? {binding, positions, exhausted} : null,
    scanned, confirmedAt: now.toISOString()};
}
export function distanceKm(a, b) {
  const rad = x => x * Math.PI / 180;
  const dLat = rad(b.latitude - a.latitude), dLon = rad(b.longitude - a.longitude);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(rad(a.latitude)) * Math.cos(rad(b.latitude)) * Math.sin(dLon / 2) ** 2;
  return 6371 * 2 * Math.atan2(Math.sqrt(h), Math.sqrt(1 - h));
}
export function validatePoint(data) {
  if (!Number.isFinite(data?.latitude) || !Number.isFinite(data?.longitude) ||
      data.latitude < 8 || data.latitude > 13 || data.longitude < 74 || data.longitude > 78) {
    throw new HttpsError('invalid-argument', 'Choose a location in Kerala.');
  }
  return {latitude: data.latitude, longitude: data.longitude};
}
export const cellFor = p => Math.floor(p.latitude * 20) + ':' + Math.floor(p.longitude * 20);
export async function nearbyStops(db, raw) {
  const point = validatePoint(raw);
  const x = Math.floor(point.latitude * 20), y = Math.floor(point.longitude * 20);
  const cells = [];
  for (let dx = -1; dx <= 1; dx++) for (let dy = -1; dy <= 1; dy++) cells.push((x + dx) + ':' + (y + dy));
  const query = db.collection('stops').where('cell', 'in', cells).where('active', '==', true).orderBy(FieldPath.documentId());
  const found = [];
  let cursor;
  for (let page = 0; page < 10; page++) {
    const result = await (cursor ? query.startAfter(cursor) : query).limit(100).get();
    for (const doc of result.docs) {
      const data = doc.data();
      const distance = distanceKm(point, data);
      if (distance <= 3) found.push({id: doc.id, name: data.name, latitude: data.latitude,
        longitude: data.longitude, routeIds: data.routeIds ?? [], distanceKm: distance});
    }
    if (result.size < 100) return {stops: found.sort((a, b) => a.distanceKm - b.distanceKm).slice(0, 8)};
    cursor = result.docs.at(-1);
  }
  throw new HttpsError('resource-exhausted', 'Nearby search is busy. Use a stop name.');
}
