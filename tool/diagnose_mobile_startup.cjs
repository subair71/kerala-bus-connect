const {chromium, webkit, devices} = require('playwright');
const fs = require('node:fs');
(async () => {
  fs.mkdirSync('startup-diagnostics', {recursive:true});
  for (const [name, engine, options] of [
    ['chromium-mobile', chromium, devices['Pixel 7']],
    ['webkit-mobile', webkit, devices['iPhone 13']],
  ]) {
    const browser = await engine.launch({headless:true});
    try {
      const page = await browser.newPage(options);
      const requests = [];
      page.on('requestfailed', request => requests.push({url:request.url(), error:request.failure()?.errorText}));
      page.on('pageerror', error => console.log(name + ' PAGE_ERROR ' + error.message));
      await page.goto('https://subair71.github.io/kerala-bus-connect/', {waitUntil:'domcontentloaded'});
      const placeholder = page.locator('flt-semantics-placeholder');
      await placeholder.waitFor({state:'attached', timeout:90000});
      await placeholder.evaluate(element => element.click());
      const failed = page.getByText('Unable to start FindMyBus. Please check your connection.', {exact:true});
      const home = page.getByText('FindMyBus', {exact:true});
      await failed.or(home).first().waitFor({timeout:90000});
      const diagnostic = await page.evaluate(() => {
        let earlyAppsError;
        try { (undefined).getApps(); } catch (error) { earlyAppsError = String(error); }
        return {firebaseCoreLoaded: !!window.firebase_core, earlyAppsError};
      });
      console.log('STARTUP_DIAGNOSTIC ' + JSON.stringify({name, failed:await failed.count(), ...diagnostic, failedRequests:requests}));
      await page.screenshot({path:'startup-diagnostics/' + name + '.png'});
    } finally { await browser.close(); }
  }
})().catch(error => {console.error(error); process.exitCode = 1;});
