// Reads unread chats off Instagram's inbox page for Unreel's message alerts.
// Runs in an invisible web view during a background check, never in the one you see.
// It only reads the page that Instagram itself rendered: it makes no requests of its own.
// The app replaces the placeholder below with the "inbox" rules and a few options.
(function () {
  "use strict";
  const cfg = __UNREEL_INBOX__;
  const started = Date.now();

  function all(selectors, root) {
    const found = [];
    for (const sel of selectors || []) {
      try { (root || document).querySelectorAll(sel).forEach((el) => found.push(el)); } catch (e) { /* bad selector */ }
    }
    return found;
  }

  function firstMatch(selectors, root) {
    for (const sel of selectors || []) {
      try { const el = (root || document).querySelector(sel); if (el) return el; } catch (e) { /* bad selector */ }
    }
    return null;
  }

  function text(el) { return ((el && el.textContent) || "").replace(/\s+/g, " ").trim(); }

  function weight(el) {
    const w = parseInt(getComputedStyle(el).fontWeight, 10);
    return isNaN(w) ? 400 : w;
  }

  // Leaf text pieces of a row, in order, with their font weight.
  function pieces(row) {
    const out = [];
    const walker = document.createTreeWalker(row, NodeFilter.SHOW_TEXT);
    let node;
    while ((node = walker.nextNode())) {
      const t = node.nodeValue.replace(/\s+/g, " ").trim();
      if (!t || !node.parentElement) continue;
      out.push({ text: t, weight: weight(node.parentElement) });
    }
    return out;
  }

  function threadId(row) {
    const link = row.matches('a[href^="/direct/t/"]') ? row : row.querySelector('a[href^="/direct/t/"]');
    const m = link && link.getAttribute("href").match(/^\/direct\/t\/([^/?#]+)/);
    return m ? m[1] : null;
  }

  function readRows(list) {
    // Outermost matching rows only, so a link inside a list item counts once.
    const rows = all(cfg.rowSelectors, list).filter((el, i, arr) =>
      arr.indexOf(el) === i && !arr.some((other) => other !== el && other.contains(el)));
    const threads = [];
    for (const row of rows) {
      const parts = pieces(row);
      if (parts.length === 0) continue;
      const nameEl = firstMatch(cfg.nameSelectors, row);
      const name = text(nameEl) || parts[0].text;
      const rest = parts.filter((p) => p.text !== name);
      const preview = rest.length ? rest[0] : null;
      const marked = all(cfg.unreadSelectors, row).length > 0;
      const bold = !!(cfg.boldPreviewMeansUnread && preview && preview.weight >= 600);
      if (!marked && !bold) continue;
      threads.push({ id: threadId(row), name: name.slice(0, 80), preview: preview ? preview.text.slice(0, 140) : null });
    }
    return { rowCount: rows.length, threads };
  }

  function badgeCount() {
    let best = null;
    for (const el of all(cfg.badgeSelectors)) {
      const n = parseInt(text(el), 10);
      if (n > 0 && n < 1000) best = Math.max(best || 0, n);
    }
    return best;
  }

  // A short outline of the chat list, so a debug run shows what Instagram's page looks like now.
  function outline(root) {
    const skip = new Set(["SCRIPT", "STYLE", "LINK", "NOSCRIPT", "META", "svg", "SVG", "path"]);
    const lines = [];
    // Depth only grows for elements that get a line, so Instagram's deep wrapper divs don't hide the content.
    (function walk(el, depth, hops) {
      if (lines.length > 400 || hops > 80 || skip.has(el.tagName)) return;
      const attrs = ["role", "aria-label", "href", "dir"].map((a) => el.getAttribute && el.getAttribute(a) ? `${a}="${el.getAttribute(a).slice(0, 40)}"` : "").filter(Boolean).join(" ");
      const own = Array.from(el.childNodes).filter((n) => n.nodeType === 3).map((n) => n.nodeValue.trim()).join(" ").slice(0, 40);
      const shown = !!(attrs || own);
      if (shown) lines.push(`${"  ".repeat(Math.min(depth, 20))}<${el.tagName.toLowerCase()} ${attrs}> ${own}${own ? ` [w${weight(el)}]` : ""}`);
      for (const child of el.children) walk(child, depth + (shown ? 1 : 0), hops + 1);
    })(root, 0, 0);
    return lines.join("\n");
  }

  function send(result) {
    try { window.webkit.messageHandlers.unreelInbox.postMessage(result); } catch (e) { /* app gone */ }
  }

  function finish(list) {
    const titleMatch = document.title.match(/^\((\d+)\)/);
    const rows = list ? readRows(list) : { rowCount: 0, threads: [] };
    send({
      path: location.pathname,
      loggedIn: !location.pathname.startsWith("/accounts/login") && !location.pathname.startsWith("/challenge"),
      listFound: !!list,
      rowCount: rows.rowCount,
      titleCount: titleMatch ? parseInt(titleMatch[1], 10) : null,
      badgeCount: badgeCount(),
      threads: rows.threads,
      outline: cfg.debug ? outline(list || document.body) : null,
    });
  }

  let listSeenAt = null;
  (function poll() {
    if (/^\/(accounts\/login|challenge)/.test(location.pathname)) return finish(null);
    const list = firstMatch(cfg.listSelectors);
    const hasRows = list && all(cfg.rowSelectors, list).length > 0;
    if (hasRows && !listSeenAt) listSeenAt = Date.now();
    // Give the list a moment to fill in after it first shows.
    if (listSeenAt && Date.now() - listSeenAt > cfg.settleMs) return finish(list);
    if (Date.now() - started > cfg.waitMs || (cfg.deadline && Date.now() > cfg.deadline)) return finish(list);
    setTimeout(poll, 250);
  })();
})();
