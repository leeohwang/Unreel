# Unreel

A free iPhone app that opens Instagram **without Reels, Explore or the endless feed**. Messages, posting, stories, search and profiles keep working. No ads, no subscription, no accounts of our own.

*Unreel is a working name. Pick any name that doesn't include "Instagram" or "Insta".*

## How it works

- A SwiftUI app shows `instagram.com` in a `WKWebView` with a Safari user agent, so Instagram serves its full mobile site. You log in normally; your session lives only in the web view on your phone.
- `Unreel/Web/cage.js` runs on every page. It watches the URL and sends you away from Reels, Explore and (optionally) the home feed, and hides links to them. Tapping the search icon goes straight to search instead of the Explore grid.
- The native side (`InstagramWebView.swift`) blocks the same paths on full page loads, opens outside links in Safari, and never hands off to the Instagram app.
- **Rules update without an App Store release.** The app downloads `config/rules.json` from this repo (at most every 5 minutes, when the app comes to the foreground) and uses it if its `version` is higher than what it has. When Instagram changes its site and something slips through, edit the patterns/selectors, bump `version`, and push to `main`.
- **Instagram's own bottom bar, minus Reels.** On pages where Instagram leaves it out (the inbox and chats) a native bar with the same icons takes its place. The header has "+" (Post / Story, through Instagram's own editor), Activity and Settings.
- **Reels friends send still play** (Settings toggle). Swiping on to more Reels returns to the chat.
- **Message alerts (optional, `Unreel/Notifications/`).** A Background App Refresh task opens `/direct/inbox/` in an invisible web view with the app's own login, reads unread chats with `inbox-probe.js` (selectors in the `inbox` section of the rules, so they can be fixed remotely) and posts local notifications. No server and no direct API calls. iOS decides when the task runs (often a few times a day, never after the app is swiped away), so Settings says alerts can be late and points to the Screen Time lock for instant ones. Debug builds: launch with `-UnreelCheckMessages` to run one check and write `Documents/inbox-probe.txt`.
- **Screen Time lock (optional, `Shared/` + `Extensions/`).** Locks the real Instagram app with FamilyControls/ManagedSettings so its notifications still arrive, but opening it shows Unreel's shield. "Open Unreel" posts a local notification that opens your messages; a posting pass lifts the lock for 5 minutes, twice a day. Offered once after the app has been used on two days.
- **Breakage reports:** cage.js reports when Instagram's page changes in a way it can't handle (bar missing, create flow failed, redirect loop, bad rules file) as an anonymous TelemetryDeck signal, once per kind per day.
- **Languages:** English, Spanish, French, German, Korean. Regenerate the `.strings` files when adding UI text.
- **On-device stats:** "X blocked today", a 7-day chart, and an estimated time saved. Stored only on the phone.
- **Optional daily limit:** after N minutes a day, a "that's enough for today" screen appears (with a "5 more minutes" escape hatch that is counted).
- **Anonymous impact metric:** one TelemetryDeck signal per user per day with counts only (Reels blocked, minutes in app, estimated minutes saved). Users can turn it off in Settings.

## Build and run (Mac required)

1. Install Xcode (free, Mac App Store) and XcodeGen: `brew install xcodegen`
2. In this folder run `xcodegen` to create `Unreel.xcodeproj`, then open it.
3. In **Signing & Capabilities**, pick your team. A free Apple ID works for running on your own iPhone; you need the paid Apple Developer Program ($99/year) to ship.
4. If `com.leeohwang.unreel` is taken, change `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml` and re-run `xcodegen`.
5. Plug in your iPhone, select it, press Run. (First time: on the phone, Settings > General > VPN & Device Management > trust your developer certificate, and turn on Developer Mode.)

### Before shipping

- `Unreel/App/Config.swift`: paste your TelemetryDeck app ID (create a free app at dashboard.telemetrydeck.com). Leave it empty to ship without analytics.
- The remote rules and privacy policy URLs must be public. Easiest: make this repo public and turn on GitHub Pages (Settings > Pages > Deploy from branch `main`, folder `/docs`). Then `docs/privacy.md` is served at `https://leeohwang.github.io/Unreel/privacy`.
- Replace the placeholder icon in `Unreel/Assets.xcassets/AppIcon.appiconset/` if you want. Keep it clearly different from Instagram's.

See [docs/APP_STORE.md](docs/APP_STORE.md) for the listing text, privacy label answers, review notes and a release checklist.

## Testing the blocking script

`node tests/cage.test.js` serves a fake instagram.com in headless Chromium (needs Playwright) and checks every redirect and hidden link. Real-device testing still matters: Instagram's markup changes, so check on an iPhone after any rules change.

## Fixing breakage after Instagram changes

1. Reproduce on a phone and note the URL path or the link that let you through.
2. Edit `config/rules.json`: `blockedPaths` are regexes on the URL path (Swift and JavaScript must both accept them; no backslashes needed for the current ones), `hideSelectors` are CSS selectors hidden everywhere, `feedSelectors` only when the feed is blocked.
3. Bump `version`, run `node tests/cage.test.js`, push. Phones pick it up the next time the app comes to the foreground (hourly at most).
4. Copy the file to `Unreel/Resources/rules.json` too, so the next release ships with it.

## Roadmap

- The Screen Time lock needs Apple's Family Controls distribution entitlement for the app and each extension before it works in TestFlight or the App Store. Request it early; it can take a week or more.
- Streaks and a weekly summary notification.

## Credits

Architecture inspired by [Konvo](https://github.com/matthewcycmb/konvo) (MIT) and similar web-view blockers. No code was copied.

Unreel is not affiliated with, endorsed by, or sponsored by Instagram or Meta. Instagram is a trademark of Meta Platforms, Inc.
