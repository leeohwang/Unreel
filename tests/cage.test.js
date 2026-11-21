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
  <a id="dm" href="/direct/inbox/">DMs</a>
  <div id="igbar" class="x1 x2-bar" style="position:fixed;bottom:0;left:0;right:0;height:50px"><div><a href="/explore/">S</a></div></div>
  <div id="dialog" style="position:fixed;top:0;bottom:0;left:0;right:0;pointer-events:none"><a href="/direct/inbox/">x</a></div></body></html>`;

async function makePage(browser, blockFeed, slowPath) {
  const page = await browser.newPage();
  page.msgs = [];
  await page.exposeFunction('__record', m => page.msgs.push(m));
  await page.route('https://www.instagram.com/**', async r => {
    if (slowPath && new URL(r.request().url()).pathname === slowPath) await new Promise(res => setTimeout(res, 2500));
    await r.fulfill({ contentType: 'text/html', body: page_html });
  });
  const cfg = { redirectPath: rules.redirectPath, blockFeed, blockedPaths: rules.blockedPaths,
                hideSelectors: rules.hideSelectors, feedSelectors: rules.feedSelectors,
                hideFixedBarsWith: rules.hideFixedBarsWith };
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
  assert.ok(await hidden(page, 'igbar'), "Instagram's bottom bar hidden");
  const learned = await page.evaluate(() => JSON.parse(localStorage.getItem('unreel.barSelectors') || '[]'));
  assert.ok(learned.length === 1 && learned[0].startsWith('div.x1.x2-bar:has('), 'bar selector learned: ' + learned);
  await page.reload();
  assert.ok(await hidden(page, 'igbar'), 'bar hidden by learned CSS after reload');
  assert.ok(!(await page.$eval('#igbar', el => el.hasAttribute('data-unreel-hidden'))), 'hidden by CSS, not by the late check');
  // A bar Instagram re-renders later is hidden by the observer before the next paint.
  const seenAfterInsert = await page.evaluate(() => new Promise(res => {
    const b = document.createElement('div');
    b.className = 'fresh'; b.style.cssText = 'position:fixed;bottom:0;left:0;right:0;height:50px';
    b.innerHTML = '<a href="/direct/inbox/">m</a>';
    document.body.appendChild(b);
    requestAnimationFrame(() => res(getComputedStyle(b).display !== 'none'));
  }));
  assert.ok(!seenAfterInsert, 'new bar hidden before the next frame');
  assert.ok(!(await hidden(page, 'dialog')), 'full-screen fixed layer not hidden');

  assert.strictEqual(await page.evaluate(() => window.__unreel.navigate('/direct/inbox/')), 'spa', 'uses an existing link');
  await settle(page);
  assert.strictEqual(pathOf(page), '/direct/inbox/', 'link navigation lands');
  await page.evaluate(() => { window.__navTest = 1; });
  assert.strictEqual(await page.evaluate(() => window.__unreel.navigate('/accounts/activity/')), 'spa-pop', 'no link: tries in-page routing');
  await page.waitForTimeout(3600); // fake page has no router, so it must fall back to a real load
  assert.strictEqual(pathOf(page), '/accounts/activity/', 'fallback load lands');
  assert.ok(await page.evaluate(() => !window.__navTest), 'page actually reloaded');

  page = await makePage(browser, false);
  await page.goto('https://www.instagram.com/');
  await settle(page);
  assert.strictEqual(pathOf(page), '/', 'feed allowed when blockFeed is off');
  assert.ok(!(await hidden(page, 'home')), 'home link visible when feed allowed');
  assert.ok(await hidden(page, 'reels'), 'reels still hidden');

  await page.evaluate(() => window.__unreel.configure(Object.assign({}, window.__unreelConfig, { blockFeed: true })));
  await settle(page);
  assert.strictEqual(pathOf(page), '/direct/inbox/', 'live reconfigure applies');

  // Slow redirect target (overloaded phone): must count once, not every timer tick.
  page = await makePage(browser, true, '/direct/inbox/');
  await page.goto('https://www.instagram.com/reels/');
  await page.waitForTimeout(3500);
  assert.strictEqual(pathOf(page), '/direct/inbox/', 'slow redirect completes');
  assert.strictEqual(page.msgs.filter(m => m.count).length, 1, 'slow redirect counted once, got ' + page.msgs.length);

  await browser.close();
  console.log('All cage.js tests passed');
})().catch(e => { console.error(e); process.exit(1); });
