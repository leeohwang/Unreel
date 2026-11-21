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
    return sels.join(',\n') + ' { display: none !important; }';
  }

  // Earlier builds learned a CSS rule that hid Instagram's bottom bar. The bar
  // is used again now (minus Reels, which hideSelectors removes), so drop it.
  try { localStorage.removeItem('unreel.barSelectors'); } catch (e) {}

  // Is Instagram's own bottom tab bar on screen? It has no role or stable class,
  // so look for a link it contains whose nearest position:fixed ancestor is a
  // short strip along the bottom. Instagram leaves the bar out on some pages
  // (the DM inbox and chats); the app shows its own tab bar there instead, so
  // nobody gets stuck.
  function igBarOnScreen() {
    var sels = cfg.igBarLinks || [];
    if (!sels.length || !document.body) return false;
    var links = document.querySelectorAll(sels.join(','));
    for (var i = 0; i < links.length; i++) {
      if (!links[i].getClientRects().length) continue; // not drawn
      for (var el = links[i].parentElement; el && el !== document.body; el = el.parentElement) {
        if (getComputedStyle(el).position !== 'fixed') continue;
        var r = el.getBoundingClientRect();
        if (r.height > 0 && r.height <= 120 && r.bottom >= innerHeight - 4) return true;
        break;
      }
    }
    return false;
  }

  // Tell the app when the bar comes and goes. "Shown" is reported at once so the
  // app's bar steps aside immediately; "gone" only after it stays gone a moment,
  // so Instagram re-rendering the bar between pages doesn't make the app's bar
  // blink in and out.
  var igBarReported = null, igBarGoneTimer = null, igBarQueued = false;
  function reportIgBar() {
    igBarQueued = false;
    if (igBarOnScreen()) {
      clearTimeout(igBarGoneTimer); igBarGoneTimer = null;
      if (igBarReported !== true) { igBarReported = true; post({ type: 'igBar', visible: true }); }
    } else if (igBarReported !== false && !igBarGoneTimer) {
      igBarGoneTimer = setTimeout(function () {
        igBarGoneTimer = null;
        if (!igBarOnScreen()) { igBarReported = false; post({ type: 'igBar', visible: false }); }
      }, 600);
    }
  }
  function queueIgBar() {
    if (igBarQueued) return;
    igBarQueued = true;
    requestAnimationFrame(reportIgBar);
  }

  // Instagram's Search button points at /explore/, which is blocked (it would
  // redirect to search with a full reload). Go straight to search in-page.
  document.addEventListener('click', function (e) {
    var a = e.target && e.target.closest && e.target.closest('a[href="/explore/"]');
    if (!a) return;
    e.preventDefault();
    e.stopPropagation();
    navigate('/explore/search/');
  }, true);

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
  var observer = new MutationObserver(function () {
    if (!styleEl || !styleEl.isConnected) applyStyle();
    queueIgBar();
  });
  observer.observe(document, { childList: true, subtree: true });

  setInterval(function () {
    check();
    if (!styleEl || !styleEl.isConnected) applyStyle();
    queueIgBar();
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
