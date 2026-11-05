const { chromium, webkit, devices } = require('playwright');
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const root = path.resolve('build/web');
const baseUrl = process.env.SMOKE_BASE_URL || 'http://127.0.0.1:8765/kerala-bus-connect/';
const types = {'.html':'text/html','.js':'text/javascript','.json':'application/json','.wasm':'application/wasm','.ttf':'font/ttf','.png':'image/png','.jpg':'image/jpeg'};
const server = http.createServer((req, res) => {
  const relative = decodeURIComponent(req.url.split('?')[0]).replace(/^\/kerala-bus-connect\/?/, '');
  const target = path.resolve(root, relative || 'index.html');
  if (!target.startsWith(root + path.sep) && target !== path.join(root, 'index.html')) { res.writeHead(403); res.end(); return; }
  fs.readFile(target, (error, data) => {
    if (error) { res.writeHead(404); res.end(); return; }
    res.setHeader('Content-Type', types[path.extname(target)] || 'application/octet-stream');
    res.end(data);
  });
});

async function verifyStartup(page) {
  const placeholder = page.locator('flt-semantics-placeholder');
  await placeholder.waitFor({state:'attached', timeout:90000});
  await placeholder.evaluate(element => {
    // Mobile Flutter enables semantics only for a centered accessibility click.
    const rect = element.getBoundingClientRect();
    element.dispatchEvent(new MouseEvent('click', {
      bubbles: true, clientX: rect.left + rect.width / 2,
      clientY: rect.top + rect.height / 2,
    }));
  });
  const failed = page.getByText('Unable to start FindMyBus. Please check your connection.', {exact:true});
  const home = page.getByText('FindMyBus', {exact:true});
  await home.or(failed).first().waitFor({timeout:90000});
  assert.equal(await failed.count(), 0, 'Firebase startup failed before the home screen');
  await home.waitFor({timeout:90000});
  assert.equal(await page.evaluate(() => window.firebase_core.getApps().length), 1,
    'The default Firebase app must be initialized exactly once');
  // Optional advertisements must never hold up the usable search form.
  await page.getByRole('button', {name:'Clear boarding stop', exact:true})
    .or(page.getByText('Clear boarding stop', {exact:true})).first()
    .waitFor({timeout:10000});
}

(async () => {
  await new Promise(resolve => server.listen(8765, '127.0.0.1', resolve));
  fs.mkdirSync('browser-screenshots', {recursive:true});
  try {
    for (const [name, engine, options] of [
      ['desktop', chromium, {viewport:{width:1440,height:1000}, deviceScaleFactor:1}],
      ['android-chrome', chromium, {...devices['Pixel 7'], deviceScaleFactor:1}],
      ['iphone-safari', webkit, {...devices['iPhone 13'], deviceScaleFactor:1}],
    ]) {
      const browser = await engine.launch({headless:true});
      try {
        const page = await browser.newPage(options);
        const errors = [];
        let phase = 'cold-start';
        page.on('pageerror', error => {
          // WebKit reports an aborted Firestore listen as a page error when the
          // old document unloads. Keep steady-state and all other errors fatal.
          if (phase === 'reload' && engine === webkit &&
              /\/firestore\.googleapis\.com\/google\.firestore\.v1\.Firestore\/Listen\/channel\?.*due to access control checks\./.test(error.message)) {
            console.log('WEB_SMOKE_RELOAD_ABORT ' + name + ': previous Firestore listener closed during navigation.');
            return;
          }
          errors.push({phase, message:error.message});
        });
        await page.goto(baseUrl, {waitUntil:'domcontentloaded'});
        await verifyStartup(page);
        await page.screenshot({path:'browser-screenshots/' + name + '-home.png'});
        if (name !== 'desktop') {
          await page.getByRole('button', {name:'Search buses', exact:true})
            .or(page.getByText('Search buses', {exact:true})).first().click();
          await page.getByText('Bus results', {exact:true}).waitFor();
          await page.screenshot({path:'browser-screenshots/' + name + '-results.png'});
          await page.getByRole('button', {name:'Close bus results', exact:true})
            .or(page.getByText('Close bus results', {exact:true})).first().click();
          await page.getByText('Bus results', {exact:true}).waitFor({state:'hidden'});
        }
        await page.locator('[aria-label^="Routes"]').or(page.getByText('Routes', {exact:false})).first().click();
        await page.getByText('Routes directory', {exact:true}).waitFor();
        assert.equal(await page.getByText('Local sponsors near Aluva', {exact:true}).count(), 0);
        await page.screenshot({path:'browser-screenshots/' + name + '-routes.png'});
        assert.deepEqual(errors, [], name + ': cold startup and navigation must not raise page errors');
        console.log('WEB_SMOKE_COLD_START_PASS ' + name);
        phase = 'reload';
        await page.reload({waitUntil:'domcontentloaded'});
        phase = 'after-reload';
        await verifyStartup(page);
        assert.deepEqual(errors, []);
        console.log('WEB_SMOKE_PASS ' + name + ': cold start, Firebase initialization, Routes navigation and reload passed.');
      } finally { await browser.close(); }
    }
  } finally { server.close(); }
})().catch(error => { console.error(error); server.close(); process.exitCode = 1; });
