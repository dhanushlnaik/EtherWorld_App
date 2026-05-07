# EtherWorld iOS — PRD

## Original problem
The app was rejected by App Store Review on March 18, 2026 (Submission ID
03a3f4d3-c263-4dc2-aef3-04006428179b) under Guideline 4.2.2 — Design / Minimum
Functionality. Apple felt the app was primarily aggregated web content with
limited native functionality, despite a previous fix attempt that added For You
personalization and an in-app privacy view.

## Goal
Add substantial native iOS functionality that fundamentally cannot be delivered
through a mobile browser, so the app passes Guideline 4.2.2 on resubmission.

## Architecture
- Native iOS Swift / SwiftUI app, deployment target iOS 16+, Xcode 16+
  (objectVersion 77 with `PBXFileSystemSynchronizedRootGroup` — new files in
  `/app/IOS_App` are picked up automatically; no `.pbxproj` edits required).
- Backend: Ghost CMS (existing) + Supabase (existing) + Firebase (existing) +
  CoinGecko public market endpoint (NEW, no API key required).

## Native features added in this PR (Jan, 2026)

### Markets tab — Crypto Watchlist
- `CryptoModels.swift`, `CryptoMarketService.swift`, `CryptoMarketViewModel.swift`,
  `CryptoWatchlistView.swift`.
- Live prices from CoinGecko, customizable watchlist, sparkline charts, auto-refresh.

### Listen Mode — Audio article reader
- `AudioReaderManager.swift`.
- AVSpeechSynthesizer-backed playback with rate control, progress, and full
  background audio.
- `IOS-App-Info.plist` updated with `UIBackgroundModes` (`audio`, `fetch`,
  `processing`, `remote-notification`).
- Inline `AudioPlayerControls` injected into `ArticleDetailView`.

### Highlights & Notes
- `HighlightsManager.swift` provides on-device JSON store, 5 colors, search.
- `AddHighlightSheet` accessible from article toolbar.
- `HighlightsView` accessible from Profile.

### Reading Stats & Streak
- `ReadingStatsManager.swift` tracks daily streak, longest streak, top topics,
  total minutes, total articles.
- `ReadingStatsView` shows streak card, 14-day chart, top topics.
- Hooked from `ArticleDetailView.onAppear`.

### Siri Shortcuts via App Intents
- `EtherworldAppIntents.swift` exposes 3 voice shortcuts:
  `OpenLatestArticleIntent`, `OpenCryptoWatchlistIntent`, `ReadLatestArticleIntent`.
- `AdaptiveContentView` listens for intent notifications to switch tabs and start
  audio playback.

### Navigation
- `AdaptiveContentView` updated to a 5-tab layout (Home, Markets, Search, Saved,
  Profile) with iPad NavigationSplitView parity. Added intent observers.

### Reviewer documentation
- `APP_REVIEW_NOTES.md` rewritten to clearly highlight the native functionality
  with a step-by-step reviewer test path.
- `APP_STORE_METADATA.md` updated.
- `README.md` checklist updated; added the Background Audio Xcode capability
  reminder.

## Manual user steps before archive / resubmit
1. In Xcode → Target → Signing & Capabilities, add **Background Modes** with
   "Audio, AirPlay, and Picture in Picture" and "Background fetch" checked.
2. Bump CFBundleVersion (build number) before re-archiving.
3. Update App Store Connect listing copy from `APP_STORE_METADATA.md`.
4. Paste reviewer notes from `APP_REVIEW_NOTES.md`.
5. Archive on a physical device run-through using the reviewer test path.

## Backlog / future enhancements (P2)
- Lock-screen / Home-screen widgets for top headlines + watchlist (separate
  WidgetKit target).
- Live Activities for breaking-news pushes.
- Highlights export to Markdown / PDF.
- Premium tier (subscription) with deeper market data + AI summaries.

## What's mocked / not implemented
- None of the new flows are mocked. Crypto data is live from CoinGecko; Listen
  Mode uses the real on-device speech synthesizer; highlights and stats are
  persisted to disk.
