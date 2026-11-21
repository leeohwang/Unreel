// Run: node tests/cage.test.js   (uses the preinstalled Playwright + Chromium)
// Serves a fake instagram.com and checks cage.js redirects and hides the right things.
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');
const assert = require('assert');

const cage = fs.readFileSync(path.join(__dirname, '../Unreel/Web/cage.js'), 'utf8');
const rules = JSON.parse(fs.readFileSync(path.join(__dirname, '../config/rules.json'), 'utf8'));
const page_html = `<!doctype html><html><head></head><body>
  <a id="home" href="/">Home</a><a id="reels" href="/reels/">Reels</a><a id="explore" href="/explore/">Search</a>
  <a id="tab" href="/someone/reels/">Profile reels</a><a id="clip" href="/someone/reel/abc/">clip</a>
  <a id="dm" href="/direct/inbox/">DMs</a></body></html>`;

async function makePage(browser, blockFeed) {
  const page = await browser.newPage();
  page.msgs = [];
  await page.exposeFunction('__record', m => page.msgs.push(m));
  await page.route('https://www.instagram.com/**', r => r.fulfill({ contentType: 'text/html', body: page_html }));
  const cfg = { redirectPath: rules.redirectPath, blockFeed, blockedPaths: rules.blockedPaths,
                hideSelectors: rules.hideSelectors, feedSelectors: rules.feedSelectors };
  await page.addInitScript(`window.webkit = { messageHandlers: { unreel: { postMessage: m => window.__record(m) } } };
    window.__unreelConfig = ${JSON.stringify(cfg)};\n${cage}`);
  return page;
}
const settle = p => p.waitForTimeout(700);
const pathOf = p => new URL(p.url()).pathname;
const hidden = (p, id) => p.$eval('#' + id, el => getComputedStyle(el).display === 'none');

(async () => {
  const browser = await chromium.launch();
  let page = await makePage(browser, true);

  await page.goto('https://www.instagram.com/');
  await settle(page);
  assert.strictEqual(pathOf(page), '/direct/inbox/', 'feed redirects to inbox');

  await page.evaluate(() => history.pushState({}, '', '/reels/'));
  await settle(page);
  assert.strictEqual(pathOf(page), '/direct/inbox/', 'SPA nav to /reels/ redirects');

  for (const p of ['/reel/xyz/', '/someone/reels/', '/someone/reel/abc/', '/explore/tags/cats/']) {
    await page.goto('https://www.instagram.com' + p);
    await settle(page);
    assert.strictEqual(pathOf(page), '/direct/inbox/', p + ' redirects to inbox');
  }
  const msgs = page.msgs;
  assert.ok(msgs.some(m => m.kind === 'explore' && m.count), 'explore grid counted');

  page.msgs = [];
  await page.goto('https://www.instagram.com/explore/');
  await settle(page);
  assert.strictEqual(pathOf(page), '/explore/search/', '/explore/ goes to search');
  assert.ok(page.msgs.length === 1 && !page.msgs[0].count, 'search redirect not counted');

  for (const p of ['/direct/t/123/', '/someone/', '/p/abc/', '/stories/someone/1/', '/accounts/login/']) {
    await page.goto('https://www.instagram.com' + p);
    await settle(page);
    assert.strictEqual(pathOf(page), p, p + ' allowed');
  }
  for (const id of ['reels', 'tab', 'clip', 'home']) assert.ok(await hidden(page, id), id + ' hidden');
  for (const id of ['dm', 'explore']) assert.ok(!(await hidden(page, id)), id + ' visible');

  page = await makePage(browser, false);
  await page.goto('https://www.instagram.com/');
  await settle(page);
  assert.strictEqual(pathOf(page), '/', 'feed allowed when blockFeed is off');
  assert.ok(!(await hidden(page, 'home')), 'home link visible when feed allowed');
  assert.ok(await hidden(page, 'reels'), 'reels still hidden');

  await page.evaluate(() => window.__unreel.configure(Object.assign({}, window.__unreelConfig, { blockFeed: true })));
  await settle(page);
  assert.strictEqual(pathOf(page), '/direct/inbox/', 'live reconfigure applies');

  await browser.close();
  console.log('All cage.js tests passed');
})().catch(e => { console.error(e); process.exit(1); });
