// Run: node tests/inbox-probe.test.js   (uses the preinstalled Playwright + Chromium)
// Serves fake inbox pages and checks inbox-probe.js reads the unread chats.
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');
const assert = require('assert');

const probe = fs.readFileSync(path.join(__dirname, '../Unreel/Web/inbox-probe.js'), 'utf8');
const rules = JSON.parse(fs.readFileSync(path.join(__dirname, '../config/rules.json'), 'utf8'));

const row = (id, name, preview, unread) => `
  <div role="listitem"><a href="/direct/t/${id}/" role="link">
    <span dir="auto" style="font-weight:600">${name}</span>
    <span dir="auto" style="font-weight:${unread ? 700 : 400}">${preview}</span>
    ${unread ? '<div aria-label="Unread"></div>' : ''}
  </a></div>`;

const pages = {
  '/direct/inbox/': `<!doctype html><title>(2) Inbox • Direct</title><body>
    <a href="/direct/inbox/"><span>2</span></a>
    <div id="later"></div>
    <script>setTimeout(() => { document.getElementById('later').innerHTML = '<div aria-label="Thread list">' +
      ${JSON.stringify(row('111', 'Ana', 'see you at 6', true) + row('222', 'Ben', 'ok', false) + row('333', 'Cy', 'lol', true))} + '</div>'; }, 600);</script>`,
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
    assert.strictEqual(r.badgeCount, 2);
    assert.deepStrictEqual(r.threads, [
      { id: '111', name: 'Ana', preview: 'see you at 6' },
      { id: '333', name: 'Cy', preview: 'lol' },
    ]);
    console.log('ok  reads unread chats, title and badge counts');

    r = await run(browser, '/direct/inbox/', { unreadSelectors: [], boldPreviewMeansUnread: true });
    assert.deepStrictEqual(r.threads.map(t => t.id), ['111', '333']);
    console.log('ok  bold last message alone marks a chat unread');

    r = await run(browser, '/accounts/login/');
    assert.strictEqual(r.loggedIn, false);
    console.log('ok  logged out is reported, not an empty inbox');

    r = await run(browser, '/direct/inbox/', { debug: true });
    assert.ok(r.outline.includes('aria-label="Thread list"'));
    console.log('ok  debug outline');
  } finally {
    await browser.close();
  }
})().catch(e => { console.error(e); process.exit(1); });
