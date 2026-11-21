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
    return sels.length ? sels.join(',\n') + ' { display: none !important; }' : '';
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
  setInterval(function () {
    check();
    if (!styleEl || !styleEl.isConnected) applyStyle();
  }, 400);

  // Opens the signed-in user's own profile. Instagram's site has no "/me" URL,
  // so ask the same endpoint the site itself uses for the current username.
  function goProfile() {
    fetch('/api/v1/accounts/current_user/?edit=true', {
      credentials: 'include',
      headers: { 'X-IG-App-ID': cfg.igAppID || '936619743392459', 'X-Requested-With': 'XMLHttpRequest' }
    })
      .then(function (r) { return r.json(); })
      .then(function (j) {
        var name = j && j.user && j.user.username;
        location.assign(name ? '/' + encodeURIComponent(name) + '/' : '/accounts/edit/');
      })
      .catch(function () { location.assign('/accounts/edit/'); });
  }

  window.__unreel = {
    configure: function (next) {
      cfg = next || {};
      compile();
      applyStyle();
      lastPath = null;
      check();
    },
    goProfile: goProfile
  };

  compile();
  applyStyle();
  check();
})();
