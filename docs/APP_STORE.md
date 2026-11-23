# App Store submission guide

## Release checklist

- [ ] Apple Developer Program membership active ($99/year)
- [ ] Family Controls (Distribution) entitlement requested and granted for the app **and** its three extensions (com.leeohwang.unreel, .shield, .shieldaction, .monitor): developer.apple.com/contact/request/family-controls-distribution. Approval can take days to weeks; without it the Screen Time lock only works in development builds. If it's not granted in time, ship v1 with the lock hidden and add it in v1.1.
- [ ] App Group `group.com.leeohwang.unreel` registered, and all four bundle IDs have it plus Family Controls enabled
- [ ] Real iPhone: lock Instagram in Settings > Screen Time, check its notifications still arrive, the shield's "Open Unreel" opens your messages, and a posting pass lifts the lock for 5 minutes
- [ ] Bundle ID registered and app created in App Store Connect (name must not contain "Instagram"/"Insta")
- [ ] TelemetryDeck app ID in `Config.swift` (or left empty)
- [ ] Repo public + GitHub Pages on, privacy URL loads
- [ ] Tested on a real iPhone: login, DMs, posting a photo and a story, search, profile; Reels/Explore tabs gone; a Reel shared in a DM plays and swiping to the next one returns to the chat; daily limit screen appears
- [ ] Screenshots (6.9" iPhone required; 6.5" optional). Blur any real people/messages, or use a test account
- [ ] Throwaway Instagram test account for the reviewer, with one friend account that has sent it a Reel in a chat (so the reviewer sees DM Reels work). Log in on a fresh device the day before submitting so it isn't stuck on a security checkpoint. Credentials go only in App Store Connect's Review Notes, never in this repo
- [ ] Product > Archive in Xcode, then Distribute App > App Store Connect
- [ ] Price: Free. Availability: all countries

## Listing

Lead with **free** everywhere: most competitors charge $5 to $10 a month, and "free, no subscription, no account" is our clearest edge.

**Name:** Unreel: Scroll-Free Social (30 chars max; avoid "Instagram")
**Subtitle:** Free. No Reels, no subscription (30 chars max; alternative: "Free Reels blocker, no account")
**First screenshot caption:** "Free forever. No subscription. No account." over the messages screen. Next screenshots: "Reels and Explore, gone", "Reels friends send still play", "Post photos and stories", "Lock the real app with Screen Time".
**Category:** Productivity (secondary: Lifestyle)
**Age rating:** 12+ or as the questionnaire says (unrestricted web access → likely 17+; answer honestly)

**Description:**

> Free. No subscription, no account, no ads. Keep your friends, lose the scroll.
>
> Unreel opens your social feed the way it should be: messages, posting, stories, search and profiles all work, but Reels and the Explore page are gone. No more "just one more video".
>
> - Reels and Explore blocked, search still works
> - A Reel a friend sends you in a chat still plays, just that one
> - Post photos and stories
> - Optional: hide the home feed and open straight to your messages, or keep a feed of only people you follow, without Reels or suggested posts
> - Optional: lock the real app with Screen Time. Its notifications still arrive, and opening it brings you back to Unreel
> - See how many Reels you skipped and how much time you saved
> - Optional daily time limit
> - In English, Spanish, French, German and Korean
> - Your stats stay on your phone
>
> Unreel is not affiliated with, endorsed by, or sponsored by Instagram or Meta.

**Keywords:** reels,blocker,scroll,focus,screen time,dopamine,detox,feed,distraction,social media,shorts

## App Privacy (nutrition label)

- Data collection: **Yes**
- Usage Data > Product Interaction. Used for: Analytics. Linked to user: **No**. Used for tracking: **No**
- (If you ship without a TelemetryDeck ID: "Data Not Collected")

## Review notes (paste into App Review Information)

> Unreel is a free digital-wellbeing app. It loads Instagram's public mobile website (instagram.com) in a WKWebView and hides the Reels and Explore sections, so people can message friends and post without endless short videos. The user logs in on Instagram's own web page; the app never sees or stores credentials, and has no accounts, servers or in-app purchases of its own. It uses no private API and does not scrape data. Unreel is not affiliated with Instagram or Meta, and uses neither name nor logo in its icon or title.
>
> Test account (Instagram): username ____ / password ____ (log in with "Log in" on the first page).
>
> What to try:
> 1. Blocking: try to open Reels or Explore from Instagram's bottom bar or a profile's Reels tab. You are returned to Messages. The Search button opens search instead of the Explore grid.
> 2. Reels from friends: open the chat with ____ and tap the Reel they sent. It plays. Swiping to the next Reel returns you to the chat.
> 3. Posting: tap "+" at the top, choose Post or Story, and pick a photo. Instagram's own editor opens (you can cancel without sharing).
> 4. Native features: the menu button (top right) opens Settings: on-device stats with a 7-day chart, feed blocking, daily time limit, Report a problem.
> 5. Screen Time (optional): Settings > Screen Time > "Lock the Instagram app" uses the Family Controls API with `.individual` authorization. The user picks apps with Apple's FamilyActivityPicker, so Unreel only sees opaque tokens. The shield's "Open Unreel" button posts a local notification that opens Unreel's messages. A posting pass lifts the shield for 5 minutes, twice a day. If the Instagram app isn't installed on the review device, the lock can be tried on any other app.

## Likely rejection reasons and answers

- **4.2 Minimum functionality / "just a website":** point to native features: Screen Time lock with shield and posting passes, native photo picker for posting, on-device stats with chart, daily limit, feed blocking, remote rule updates, five languages.
- **5.1.1 / Family Controls:** the entitlement must be granted for every target before submission; explain in the note that the picker returns only opaque tokens and nothing leaves the phone.
- **5.2.1 Intellectual property:** no Instagram name or logo in the app name, icon or screenshots' captions; keep the "not affiliated" line. Konvo and others were approved with this setup.
- **2.1 Couldn't log in:** always give a working test account, and check it isn't stuck on a security checkpoint before submitting.
- **4.3 Spam:** our code is original; don't copy another app's listing text or screenshots.
