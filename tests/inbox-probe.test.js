// Run: node tests/inbox-probe.test.js   (uses the preinstalled Playwright + Chromium)
// Serves fake inbox pages and checks inbox-probe.js reads the unread chats.
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');
const assert = require('assert');

const probe = fs.readFileSync(path.join(__dirname, '../Unreel/Web/inbox-probe.js'), 'utf8');
const rules = JSON.parse(fs.readFileSync(path.join(__dirname, '../config/rules.json'), 'utf8'));

// Shaped like Instagram's mobile inbox (Nov 2026): rows are div[role=button] with an <abbr> time,
// inside div[role=navigation] next to header and notes buttons that must not count.
const row = (name, preview, unread) => `
  <div role="button">
    <span dir="auto"><span style="font-weight:${unread ? 600 : 400}">${name}</span></span>
    <span dir="auto"><span style="font-weight:${unread ? 600 : 400}">${preview}</span></span>
    <span>·</span><span dir="auto"><abbr aria-label="2 hours ago"><span>2h</span></abbr></span>
  </div>`;
const chrome = `<div role="button"><h2 dir="auto"><span style="font-weight:700">me</span></h2></div>
  <a role="link" href="/direct/new/"></a>
  <div role="presentation"><div role="button"><div>Weekend plans?</div><span dir="auto">Your note</span></div></div>
  <h1 dir="auto" style="font-weight:700">Messages</h1><a role="link" href="/direct/requests/">Requests</a>`;

const pages = {
  '/direct/inbox/': `<!doctype html><title>(2) Inbox • Direct</title><body>
    <div id="later"></div>
    <script>setTimeout(() => { document.getElementById('later').innerHTML = '<div role="navigation">' +
      ${JSON.stringify(chrome + row('Ana', 'see you at 6', true) + row('Ben', 'ok', false) + row('Cy', 'lol', true))} + '</div>'; }, 600);</script>`,
  '/accounts/login/': `<!doctype html><title>Login</title><body><form></form>`,
};

async function run(browser, startPath, extra = {}) {
  const page = await browser.newPage();
  await page.route('https://www.instagram.com/**', r => {
    const p = new URL(r.request().url()).pathname;
    r.fulfill({ contentType: 'text/html', body: pages[p] || '<body></body>' });
  });
  const cfg = Object.assign({}, rules.inbox, { waitMs: 4000, settleMs: 300, debug: false }, extra);
  let done;
  const result = new Promise((res, rej) => { done = res; setTimeout(() => rej(new Error('no result from ' + startPath)), 8000); });
  await page.exposeFunction('__done', m => done(m));
  page.on('pageerror', e => console.error('page error:', e.message));
  await page.addInitScript(`window.webkit = { messageHandlers: { unreelInbox: { postMessage: m => window.__done(m) } } };`);
  await page.addInitScript(`document.addEventListener('DOMContentLoaded', () => { ${probe.replaceAll('__UNREEL_INBOX__', JSON.stringify(cfg))} });`);
  await page.goto('https://www.instagram.com' + startPath);
  const r = await result;
  await page.close();
  return r;
}

(async () => {
  const browser = await chromium.launch();
  try {
    let r = await run(browser, '/direct/inbox/');
    assert.strictEqual(r.loggedIn, true);
    assert.strictEqual(r.listFound, true);
    assert.strictEqual(r.rowCount, 3);
    assert.strictEqual(r.titleCount, 2);
    assert.strictEqual(r.badgeCount, null);
    assert.deepStrictEqual(r.threads, [
      { id: null, name: 'Ana', preview: 'see you at 6' },
      { id: null, name: 'Cy', preview: 'lol' },
    ]);
    console.log('ok  reads unread chats and skips header and notes buttons');

    r = await run(browser, '/direct/inbox/', { boldPreviewMeansUnread: false });
    assert.deepStrictEqual(r.threads, []);
    console.log('ok  without the bold rule nothing counts as unread');

    r = await run(browser, '/accounts/login/');
    assert.strictEqual(r.loggedIn, false);
    console.log('ok  logged out is reported, not an empty inbox');

    r = await run(browser, '/direct/inbox/', { debug: true });
    assert.ok(r.outline.includes('Ana'));
    console.log('ok  debug outline');
  } finally {
    await browser.close();
  }
})().catch(e => { console.error(e); process.exit(1); });
