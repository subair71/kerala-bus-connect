import {FieldPath} from 'firebase-admin/firestore';
export async function rollupDimensions(db, day) {
  const totals = {route: new Map(), stop: new Map()};
  let cursor;
  const base = db.collection('usage_dimensions').where('day', '==', day).orderBy(FieldPath.documentId());
  while (true) {
    const page = await (cursor ? base.startAfter(cursor) : base).limit(200).get();
    for (const doc of page.docs) {
      const row = doc.data(), map = totals[row.type];
      if (map) map.set(row.dimensionId, (map.get(row.dimensionId) ?? 0) + row.count);
    }
    if (page.size < 200) break;
    cursor = page.docs.at(-1);
  }
  const result = {};
  for (const type of ['route', 'stop']) result[type] = [...totals[type]]
    .sort((a,b) => b[1]-a[1]).slice(0, 20).map(([id, count]) => ({id, count}));
  await db.doc('analytics_summaries/' + day).set({day, ...result, measuredOnly: true});
}
export async function analyticsDashboard(db, now = Date.now()) {
  const day = new Date(now + 330 * 60000).toISOString().slice(0,10), month = day.slice(0,7);
  const [daily, monthly, popular, advertising] = await Promise.all([
    db.collection('usage_daily').where('day','==',day).limit(32).get(),
    db.collection('usage_monthly').where('month','==',month).limit(32).get(),
    db.doc('analytics_summaries/' + day).get(),
    db.doc('platform_metrics/advertising').get(),
  ]);
  const summary = {id: 'usage-' + day, day, month, scope: 'Opt-in measured installations; not all registered users'};
  for (const doc of [...daily.docs, ...monthly.docs]) for (const [key, value] of Object.entries(doc.data())) {
    if (typeof value === 'number') summary[key] = (summary[key] ?? 0) + value;
  }
  return {records: [summary, {id: 'advertising', ...advertising.data()},
    ...['route','stop'].flatMap(type => (popular.data()?.[type] ?? []).map(row =>
      ({id: row.id, type, searchCount: row.count})))], cursor: null};
}
