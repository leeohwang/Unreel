# App Store submission guide

## Release checklist

- [ ] Apple Developer Program membership active ($99/year)
- [ ] Bundle ID registered and app created in App Store Connect (name must not contain "Instagram"/"Insta")
- [ ] TelemetryDeck app ID in `Config.swift` (or left empty)
- [ ] Repo public + GitHub Pages on, privacy URL loads
- [ ] Tested on a real iPhone: login, DMs, posting a story, search, profile; Reels/Explore tabs gone; tapping a Reel shared in a DM is blocked; daily limit screen appears
- [ ] Screenshots (6.9" iPhone required; 6.5" optional). Blur any real people/messages, or use a test account
- [ ] Throwaway Instagram test account for the reviewer (put credentials in Review Notes)
- [ ] Product > Archive in Xcode, then Distribute App > App Store Connect
- [ ] Price: Free. Availability: all countries

## Listing

**Name:** Unreel: Scroll-Free Social (30 chars max; avoid "Instagram")
**Subtitle:** Messages without Reels
**Category:** Productivity (secondary: Lifestyle)
**Age rating:** 12+ or as the questionnaire says (unrestricted web access → likely 17+; answer honestly)

**Description:**

> Keep your friends, lose the scroll.
>
> Unreel opens your social feed the way it should be: messages, posting, stories, search and profiles all work, but Reels and the Explore page are gone. No more "just one more video".
>
> - Reels and Explore blocked, search still works
> - Optional: hide the home feed and open straight to your messages
> - See how many Reels you skipped today and how much time you saved
> - Optional daily time limit
> - Free. No ads, no subscription, no sign-up
> - Your stats stay on your phone
>
> Unreel is not affiliated with, endorsed by, or sponsored by Instagram or Meta.

**Keywords:** reels,blocker,scroll,focus,screen time,dopamine,detox,feed,distraction,social media,shorts

## App Privacy (nutrition label)

- Data collection: **Yes**
- Usage Data > Product Interaction. Used for: Analytics. Linked to user: **No**. Used for tracking: **No**
- (If you ship without a TelemetryDeck ID: "Data Not Collected")

## Review notes (paste into App Review Information)

> Unreel is a free digital-wellbeing browser for instagram.com. It loads Instagram's public mobile website in a WKWebView and hides the Reels and Explore sections so people can message friends without endless short videos. The user logs in on Instagram's own website; the app never handles credentials. It does not use any private API, scrape data, or modify Instagram's servers.
>
> Test account (Instagram): username ____ / password ____
>
> To see the blocking: log in, then tap a link to Reels or Explore (or open a Reel shared in Messages). You'll be returned to Messages and the counter at the top increases. Tap the counter for stats, and the gear for settings (daily limit, feed blocking).

## Likely rejection reasons and answers

- **4.2 Minimum functionality / "just a website":** point to native features: on-device stats with chart, daily limit, feed blocking, remote rule updates, native handling of links. Add more native features if needed (streaks, weekly summary notification).
- **5.2.1 Intellectual property:** no Instagram name or logo in the app name, icon or screenshots' captions; keep the "not affiliated" line. Konvo and others were approved with this setup.
- **2.1 Couldn't log in:** always give a working test account, and check it isn't stuck on a security checkpoint before submitting.
- **4.3 Spam:** our code is original; don't copy another app's listing text or screenshots.
