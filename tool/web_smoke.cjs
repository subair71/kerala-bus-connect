const { chromium } = require('playwright');
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const root = path.resolve('build/web');
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
(async () => {
  await new Promise(resolve => server.listen(8765, '127.0.0.1', resolve));
  const browser = await chromium.launch({headless: true});
  fs.mkdirSync('browser-screenshots', {recursive: true});
  try {
    for (const [name, viewport] of [['desktop', {width:1440,height:1000}], ['mobile', {width:390,height:844}]]) {
      const page = await browser.newPage({viewport, deviceScaleFactor:1});
      const errors = [];
      page.on('pageerror', error => errors.push(error.message));
      await page.goto('http://127.0.0.1:8765/kerala-bus-connect/', {waitUntil:'domcontentloaded'});
      const semantics = page.locator('flt-semantics-placeholder');
      await semantics.waitFor({state:'attached', timeout:60000});
      await semantics.evaluate(element => element.click());
      await page.getByText('FindMyBus', {exact:true}).waitFor({timeout:60000});
      await page.getByText('Local sponsors near Aluva', {exact:true}).waitFor({timeout:60000});
      await page.screenshot({path:'browser-screenshots/' + name + '-home.png'});
      await page.locator('[aria-label^="Routes"]').or(page.getByText('Routes', {exact:false})).first().click();
      await page.getByText('Routes directory', {exact:true}).waitFor();
      assert.equal(await page.getByText('Local sponsors near Aluva', {exact:true}).count(), 0);
      await page.screenshot({path:'browser-screenshots/' + name + '-routes.png'});
      assert.deepEqual(errors, []);
      console.log('WEB_SMOKE_PASS ' + name + ': Flutter loaded, Firebase/sample display rendered, Routes opened without ads, no uncaught JS errors.');
      await page.close();
    }
  } finally { await browser.close(); server.close(); }
})().catch(error => { console.error(error); server.close(); process.exitCode = 1; });
