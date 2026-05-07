# App Review Notes — Resubmission for Guideline 4.2.2 (Minimum Functionality)

Submission target: Resubmission after rejection dated March 18, 2026 (Submission ID 03a3f4d3-c263-4dc2-aef3-04006428179b).

---

## Copy / Paste into App Store Connect "Notes for Review"

Hello App Review Team,

Thank you for your continued feedback. We have substantially expanded EtherWorld's
native functionality in this build so the app is no longer a content-aggregation
experience. The following capabilities are now first-class native features that
work entirely in-app and cannot be replicated by browsing a website.

### What is new in this build (substantial native functionality)

1. **Crypto Markets — live watchlist (Markets tab)**
   - Native, in-app cryptocurrency tracker with real-time prices for any coin.
   - Customizable watchlist (add / remove / reorder coins).
   - 7-day sparkline charts, 24-hour high / low, volume, market cap.
   - Auto-refresh every 60 seconds; pull-to-refresh; offline last-known values.
   - Powered by the public CoinGecko market endpoint. No external browser required.

2. **Listen Mode — native audio reading of articles**
   - Every article includes a native AVSpeechSynthesizer-driven listen mode with
     play / pause / stop, adjustable speech rate (0.75x → 1.5x), and a progress bar.
   - Background audio is supported via the `audio` UIBackgroundMode, so users can
     lock the device or switch apps while listening.
   - Audio session is configured for spoken-audio playback and ducks other audio.

3. **Highlights & Personal Notes**
   - Users can save passages from any article with five highlight colors and an
     optional personal note (entirely on-device, stored in JSON).
   - A native Highlights & Notes hub (Profile → Highlights & Notes) supports
     search, color filtering, swipe-to-delete, and export-style browsing.

4. **Reading Stats & Daily Streak**
   - Native streak tracker (current / longest), total articles read, total minutes,
     a 14-day reading bar chart, and a "Top topics" leaderboard derived from the
     user's reading history.
   - All data is computed and stored on-device.

5. **Siri Shortcuts via App Intents**
   - "Show my crypto watchlist in EtherWorld"
   - "Read me the latest EtherWorld article"
   - "Open the latest article in EtherWorld"
   - These intents are registered through `AppShortcutsProvider` and trigger native
     in-app navigation / playback.

### Native functionality previously available (still present)

- Multi-provider native authentication (Apple, Google, OTP email).
- For You feed with topic personalization and onboarding.
- Saved articles, read state, offline article and image caching.
- Native push notification preferences with quiet hours.
- Native search / discovery and author profile views.
- Native settings, profile, privacy policy and data export screens.
- iPad-optimized layout with a NavigationSplitView sidebar.
- Spotlight indexing of articles for system-wide search.
- Deep link handling (etherworld:// URL scheme).

### Why this clearly exceeds a web-browsing experience

- The Markets tab is a fully native financial tracker that has no equivalent on
  etherworld.co — coins, prices, sparklines and watchlist persistence are entirely
  device-side.
- Listen mode uses on-device speech synthesis and background audio. This cannot
  be reproduced by a mobile browser.
- Highlights, notes, and reading-streak stats are all stored locally on the device
  and provide a personal reading journal that is only meaningful inside the app.
- Siri / App Intents integration provides native voice control.

---

## Reviewer Test Path (Fast)

1. Launch app and sign in (Apple, Google, or Email OTP).
2. Personalization onboarding appears — choose a few topics, then Continue.
3. **Markets tab**: tap Markets in the bottom bar. The default watchlist (BTC, ETH,
   SOL, ADA, DOT) loads with live prices and sparklines. Pull to refresh.
4. Tap "+" → search "polygon" → tap a result to add to the watchlist. Long-press
   any row to reorder; swipe left to remove.
5. Tap any coin to see the detail view with a 7-day sparkline and stats.
6. **Home tab**: open any article. The "Listen to article" controls are visible
   below the title — tap play and lock the device to confirm background audio.
7. Tap the highlighter icon in the article toolbar, paste / type a passage, pick a
   color, optionally add a note, tap Save.
8. **Profile tab → Reading Stats & Streak**: confirm the streak card, articles-read
   count, 14-day chart and top topics populated.
9. **Profile tab → Highlights & Notes**: confirm the saved highlight appears and
   filter by color works; swipe left to delete.
10. **Siri**: from the iOS settings, search "EtherWorld" — three voice shortcuts
    are registered and can be invoked from Siri.
11. Open Settings → Privacy Policy (in-app native view).
12. Internal article links stay in-app; external links open intentionally in
    Safari and are clearly marked "(Opens in Safari)".

---

## Internal Pre-Submission Checklist

- [ ] Verify Markets tab loads coins on cold launch with no network errors.
- [ ] Verify watchlist add / remove / reorder persists across app launches.
- [ ] Verify Listen Mode plays in foreground, continues with screen locked,
        respects rate changes, and stops on user request.
- [ ] Verify Highlights are persisted and survive a relaunch.
- [ ] Verify Reading Stats streak increments after reading at least one article today.
- [ ] Verify Siri shortcut "Read me the latest EtherWorld article" begins playback.
- [ ] Verify For You / Latest feed toggle still functions.
- [ ] Verify internal vs external article link policy unchanged.
- [ ] Verify offline open of a previously viewed / saved article still works.
- [ ] Verify Apple, Google, OTP login regressions are clean.
- [ ] Verify the Background Modes (audio, fetch, processing, remote-notification)
        capability is enabled in the project before archiving.

---

## "What's New" copy (App Store)

- New **Markets tab**: a native crypto watchlist with live prices, sparklines,
  and customizable coin tracking.
- New **Listen Mode**: hear articles read aloud with background audio playback
  and adjustable speed.
- New **Highlights & Notes**: save passages with five colors and personal notes,
  searchable in a dedicated hub.
- New **Reading Stats & Daily Streak**: track your reading habit with a streak
  card, 14-day chart and your top topics.
- New **Siri Shortcuts** for opening the latest article, reading aloud, and the
  watchlist.
- Improved in-app reading flow with clearer link behavior.
