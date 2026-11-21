// Unreel page script. Injected at document start into instagram.com.
// It never reads page content. It only watches the URL path, sends the visitor
// away from Reels / Explore / the feed, and hides links to them.
// window.__unreelConfig is set by the app right before this script runs.
(function () {
  if (window.__unreel) return;

  var cfg = window.__unreelConfig || {};
  var rules = [];
  var styleEl = null;
  var lastPath = null;
  // Set once we start leaving a blocked page. location.replace() is not instant
  // (seconds on a slow device), and without this the 400 ms timer would fire
  // replace() again and again: overcounting blocks and restarting the load.
  var redirecting = false;

  function post(msg) {
    try { window.webkit.messageHandlers.unreel.postMessage(msg); } catch (e) {}
  }

  function compile() {
    rules = [];
    (cfg.blockedPaths || []).forEach(function (r) {
      if (r.kind === 'feed' && !cfg.blockFeed) return;
      try { rules.push({ re: new RegExp(r.pattern), rule: r }); } catch (e) {}
    });
  }

  function cssText() {
    var sels = (cfg.hideSelectors || []).slice();
    if (cfg.blockFeed) sels = sels.concat(cfg.feedSelectors || []);
    sels.push('[data-unreel-hidden]');
    sels = sels.concat(learnedBars());
    return sels.join(',\n') + ' { display: none !important; }';
  }

  // Selectors for Instagram's bottom bar learned on earlier pages and loads, so
  // CSS hides it before it is ever drawn instead of after we spot it.
  var LEARNED_KEY = 'unreel.barSelectors';
  function learnedBars() {
    try {
      var list = JSON.parse(localStorage.getItem(LEARNED_KEY) || '[]');
      return Array.isArray(list) ? list.filter(function (x) { return typeof x === 'string'; }) : [];
    } catch (e) { return []; }
  }
  // Instagram's class names are atomic utility classes, so the bar's full class
  // list plus ":has(<one of its links>)" pins it down without catching
  // anything else.
  function learnBar(el, linkSelectors) {
    var classes = (el.getAttribute('class') || '').split(/\s+/).filter(function (c) {
      return /^[A-Za-z_][\w-]*$/.test(c);
    });
    if (!classes.length) return;
    var sel = el.tagName.toLowerCase() + '.' + classes.join('.') + ':has(' + linkSelectors.join(',') + ')';
    try { if (!document.querySelector(sel)) return; } catch (e) { return; } // unsupported or wrong
    var list = learnedBars();
    if (list.indexOf(sel) !== -1) return;
    list.unshift(sel);
    try { localStorage.setItem(LEARNED_KEY, JSON.stringify(list.slice(0, 6))); } catch (e) { return; }
    applyStyle();
  }

  // Instagram's own bottom tab bar has no role or stable class to select, so
  // find it from a link it contains: the nearest position:fixed ancestor that
  // is a short strip along the bottom of the screen. The app shows its own tab
  // bar instead. Size checks keep this from ever hiding a whole page or dialog.
  function hideFixedBars() {
    var sels = cfg.hideFixedBarsWith || [];
    if (!sels.length || !document.body) return;
    var links = document.querySelectorAll(sels.join(','));
    for (var i = 0; i < links.length; i++) {
      if (links[i].closest('[data-unreel-hidden]')) continue; // already hidden
      if (!links[i].getClientRects().length) continue;         // not drawn (e.g. hidden by learned CSS)
      for (var el = links[i].parentElement; el && el !== document.body; el = el.parentElement) {
        if (getComputedStyle(el).position !== 'fixed') continue;
        var r = el.getBoundingClientRect();
        if (r.height > 0 && r.height <= 120 && r.bottom >= innerHeight - 4) {
          el.setAttribute('data-unreel-hidden', '');
          learnBar(el, sels);
        }
        break;
      }
    }
  }

  function applyStyle() {
    if (!styleEl) {
      styleEl = document.createElement('style');
      styleEl.id = 'unreel-style';
    }
    styleEl.textContent = cssText();
    var parent = document.head || document.documentElement;
    if (parent && styleEl.parentNode !== parent) parent.appendChild(styleEl);
  }

  function check() {
    if (redirecting) return;
    var path = location.pathname;
    if (path === lastPath) return;
    lastPath = path;
    var fallback = cfg.redirectPath || '/direct/inbox/';
    for (var i = 0; i < rules.length; i++) {
      if (!rules[i].re.test(path)) continue;
      var r = rules[i].rule;
      var target = r.redirect || fallback;
      if (target === path) return; // never loop
      redirecting = true;
      post({ type: 'blocked', kind: r.kind, count: r.count !== false });
      location.replace(target);
      return;
    }
  }

  ['pushState', 'replaceState'].forEach(function (name) {
    var original = history[name];
    history[name] = function () {
      var result = original.apply(this, arguments);
      setTimeout(check, 0);
      return result;
    };
  });
  window.addEventListener('popstate', check);
  document.addEventListener('DOMContentLoaded', applyStyle);
  // Hide Instagram's bar as soon as it is added to the page. Observer callbacks
  // run before the browser paints, so it is never seen.
  var observer = new MutationObserver(function () {
    if (!styleEl || !styleEl.isConnected) applyStyle();
    hideFixedBars();
  });
  observer.observe(document, { childList: true, subtree: true });

  setInterval(function () {
    check();
    if (!styleEl || !styleEl.isConnected) applyStyle();
    hideFixedBars();
  }, 400);

  // Opens the signed-in user's own profile. Instagram's site has no "/me" URL.
  // (Its current_user API answers 400 "spam" to scripted calls, so don't use it.)
  // The page embeds the viewer's data: the "username" nearest the viewer's id
  // (the ds_user_id cookie) is theirs. Fall back to Instagram's own profile link,
  // then to Edit profile, which at least shows the account.
  function ownUsername() {
    var uid = (document.cookie.match(/(?:^|;\s*)ds_user_id=(\d+)/) || [])[1];
    var html = document.documentElement.innerHTML;
    if (uid) {
      var ids = [], m, re = new RegExp('"id":"' + uid + '"', 'g');
      while ((m = re.exec(html))) ids.push(m.index);
      var best = null, bestDist = 2000, ure = /"username":"([A-Za-z0-9._]{1,30})"/g;
      while ((m = ure.exec(html))) {
        for (var i = 0; i < ids.length; i++) {
          var d = Math.abs(ids[i] - m.index);
          if (d < bestDist) { bestDist = d; best = m[1]; }
        }
      }
      if (best) return best;
    }
    var imgs = document.querySelectorAll('a[href] img[alt]');
    for (var j = 0; j < imgs.length; j++) {
      var href = imgs[j].closest('a').getAttribute('href') || '';
      if (/profile picture/i.test(imgs[j].alt) && /^\/[A-Za-z0-9._]+\/$/.test(href)) return href.slice(1, -1);
    }
    return null;
  }

  // Moves to `path` the fast way when possible. Instagram is a single-page app:
  // clicking one of its own links (its hidden bottom bar keeps them in the page)
  // lets its router swap the view in place, without reloading the whole site.
  // Falls back to a normal page load.
  function navigate(path) {
    if (location.pathname === path) return 'same';
    var link = document.querySelector('a[href="' + path.replace(/"/g, '') + '"]');
    if (link) { link.click(); return 'spa'; }
    // No link on this page (e.g. the DM inbox). Instagram's router listens
    // for popstate, so push the URL and let it render in-page instead of
    // paying a ~10s full reload. If nothing re-renders, do a real load.
    try {
      history.pushState({}, '', path);
      var changed = false;
      var mo = new MutationObserver(function () { changed = true; mo.disconnect(); });
      mo.observe(document.body, { childList: true, subtree: true });
      dispatchEvent(new PopStateEvent('popstate', { state: {} }));
      setTimeout(function () {
        mo.disconnect();
        if (!changed) location.assign(path);
      }, 3000);
      return 'spa-pop';
    } catch (e) {
      location.assign(path);
      return 'load';
    }
  }

  function goProfile() {
    var name = null;
    try { name = ownUsername(); } catch (e) {}
    return navigate(name ? '/' + encodeURIComponent(name) + '/' : '/accounts/edit/');
  }

  window.__unreel = {
    configure: function (next) {
      cfg = next || {};
      compile();
      applyStyle();
      lastPath = null;
      check();
    },
    goProfile: goProfile,
    navigate: navigate
  };

  compile();
  applyStyle();
  check();
})();
