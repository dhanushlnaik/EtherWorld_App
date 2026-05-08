# EtherWorld iOS App

A native iOS app for crypto and blockchain readers — articles, live market prices, listen-mode audio, highlights, and reading stats — built with SwiftUI.

## App Details

- **Name**: EtherWorld
- **Bundle ID**: co.etherworld.app
- **Version**: 1.0 (build number must be bumped before re-archive)
- **Platform**: iOS 16.0+, iPadOS 16.0+

---

## 🆕 Latest Changes — App Store 4.2.2 Remediation (Jan 2026)

> Apple rejected v1.0 build 1 on **March 18, 2026** under Guideline **4.2.2 — Minimum Functionality** (Submission ID `03a3f4d3-c263-4dc2-aef3-04006428179b`), citing "limited or no native functionality" beyond aggregated web content. This release adds substantial native iOS-only capabilities that fundamentally cannot be reproduced by a mobile browser.

### What was added

| Feature | Files | Why it satisfies 4.2.2 |
|---|---|---|
| **Markets tab** — live crypto watchlist (CoinGecko) with sparkline charts, add/remove/reorder, 60-second auto-refresh, search-to-add, coin detail with stats | `CryptoModels.swift`, `CryptoMarketService.swift`, `CryptoMarketViewModel.swift`, `CryptoWatchlistView.swift` | A native financial tracker not present on etherworld.co; data persisted on-device. |
| **Listen Mode** — `AVSpeechSynthesizer`-driven audio reader on every article with play/pause/stop, speed control (0.75×–1.5×), progress bar, and **background audio** | `AudioReaderManager.swift` (+ inline `AudioPlayerControls`), `IOS-App-Info.plist` (UIBackgroundModes) | On-device speech synthesis and background-locked playback are device-only capabilities. |
| **Highlights & Notes** — five-color highlights with personal notes per article, on-device JSON store, dedicated browse hub with search and color filtering | `HighlightsManager.swift` (+ `AddHighlightSheet`, `HighlightsView`) | A personal reading journal stored locally; meaningless without the app. |
| **Reading Stats & Streak** — daily streak (current + longest), total articles, total minutes, 14-day reading chart, top topics leaderboard | `ReadingStatsManager.swift` (+ `ReadingStatsView`) | All computed and persisted on-device. |
| **Siri Shortcuts** via App Intents — "Read me the latest EtherWorld article", "Show my crypto watchlist in EtherWorld", "Open the latest article in EtherWorld" | `EtherworldAppIntents.swift` | Native voice control wired to in-app navigation and audio playback. |

### Files modified

- `IOS_App/AdaptiveContentView.swift` — added 5th **Markets** tab on iPhone, sidebar entry on iPad, and observers for the three App Intent notifications.
- `IOS_App/ArticleDetailView.swift` — inline `AudioPlayerControls` below the title, "highlighter" toolbar button, and reading-stats logging on appear.
- `IOS_App/ProfileSettingsView.swift` — new "Reading" section linking to **Reading Stats & Streak** and **Highlights & Notes**.
- `IOS_App/IOS-App-Info.plist` — added `UIBackgroundModes` (`audio`, `fetch`, `processing`, `remote-notification`).
- `APP_REVIEW_NOTES.md` — rewritten with a 12-step reviewer test path tied to the new features.
- `APP_STORE_METADATA.md` — updated subtitle, description, keywords, and reviewer notes for resubmission.
- `memory/PRD.md` — full product record of the remediation work.

### Required manual steps before re-archiving

1. **Xcode** → target **IOS_App** → **Signing & Capabilities** → **+ Capability** → **Background Modes** → check **Audio, AirPlay, and Picture in Picture** + **Background fetch**. *(The Info.plist key is already set; Xcode also needs the capability checkbox enabled.)*
2. **Bump the build number** (`CURRENT_PROJECT_VERSION`) before archiving.
3. Walk through the reviewer test path in `APP_REVIEW_NOTES.md` on a physical device.
4. Paste the new "Notes for Review" text from `APP_REVIEW_NOTES.md` into App Store Connect when resubmitting.
5. Update the App Store Connect listing copy from `APP_STORE_METADATA.md`.

### How to view the diff

```bash
cd /app
git status              # all touched files
git diff --stat         # per-file additions/deletions summary
git diff IOS_App/AdaptiveContentView.swift   # one specific file
```

In Xcode: open `IOS_App.xcodeproj` → **Source Control navigator** (⌥⌘2) for line-level diffs.

> The Xcode project uses synchronized folders (`PBXFileSystemSynchronizedRootGroup`, `objectVersion 77`), so all new Swift files are picked up automatically. **No `project.pbxproj` edits are required.**

---

## Features

### Authentication
- ✅ Apple Sign In
- ✅ Google Sign In  
- ✅ OTP via Email (6-digit verification code)
- ✅ Firebase Authentication

### Native Reader Features (4.2.2 hardening)
- ✅ **Markets tab** — live crypto watchlist with sparkline charts (CoinGecko)
- ✅ **Listen Mode** — TTS audio playback per article with speed control + background audio
- ✅ **Highlights & Notes** — 5 colors, personal notes, on-device search
- ✅ **Reading Stats & Streak** — daily streak, 14-day chart, top topics
- ✅ **Siri Shortcuts** via App Intents (latest article / listen aloud / watchlist)

### Core Features
- ✅ Browse articles from Ghost CMS
- ✅ For You feed with topic personalization (and Latest mode)
- ✅ Search with language filtering
- ✅ Bookmark/Save articles for offline reading
- ✅ Mark articles as read
- ✅ Offline mode with local caching
- ✅ Background refresh
- ✅ Push notifications
- ✅ Multi-language support (EN, ES, FR, DE, etc.)
- ✅ Dark/Light/System theme
- ✅ iPad optimized with sidebar
- ✅ Author profiles
- ✅ Share articles
- ✅ Spotlight indexing of articles

### Privacy & Data
- ✅ Privacy Policy view
- ✅ Data export capability
- ✅ Session details (active session UI)
- ✅ Analytics (opt-in)
- ✅ Account deletion
- ✅ Supabase integration for preferences sync

## Configuration

### Required Files
1. `Config.xcconfig` - API keys and configuration
2. `GoogleService-Info.plist` - Firebase configuration
3. `IOS-App-Info.plist` - App configuration and permissions

### API Keys (in Config.xcconfig)
- Ghost CMS API Key
- Ghost Base URL
- Supabase URL
- Supabase Anon Key
- Firebase (configured via GoogleService-Info.plist)

## Privacy Permissions

The app requests the following permissions:
- **Background fetch**: Article updates
- **Background audio**: Listen Mode (text-to-speech) keeps playing when the screen is locked or the app is backgrounded

## App Store Submission Checklist

### Technical Requirements
- [x] Bundle ID configured: `co.etherworld.app`
- [x] Version numbers set: 1.0 (Build 1)
- [x] App icon configured (1024x1024)
- [x] Launch screen with logo
- [x] Privacy descriptions added
- [x] App Transport Security configured
- [x] Firebase Bundle ID updated
- [x] Remove dev/demo login path before production
- [ ] Test on physical device

### Testing Requirements
- [x] Test Apple Sign In
- [x] Test Google Sign In
- [x] Test Magic Link authentication
- [x] Test offline mode (airplane mode)
- [x] Test bookmarking and read status
- [x] Test background refresh
- [x] Test on iPad
- [x] Test theme switching
- [ ] Test language switching
- [ ] Test push notifications

### App Store Connect
- [ ] Create app listing
- [ ] Upload screenshots (6.7" iPhone, 12.9" iPad Pro)
- [ ] Add app description
- [ ] Add keywords
- [ ] Set support URL: https://etherworld.co
- [ ] Set privacy policy URL: https://etherworld.co/privacy
- [ ] Configure in-app purchases (if any)
- [ ] Submit for review
- [x] Finalized listing copy: see `APP_STORE_METADATA.md`

### 4.2.2 Re-Submission Assets
- [x] Native functionality remediation implemented (in-app navigation policy, in-app privacy access, personalization onboarding)
- [x] **NEW** Markets tab: native crypto watchlist (CoinGecko) with sparklines, add/remove/reorder, auto-refresh
- [x] **NEW** Listen Mode: native AVSpeechSynthesizer audio playback with background audio + speed control
- [x] **NEW** Highlights & Notes: 5 colors, personal notes, search, on-device persistence
- [x] **NEW** Reading Stats & Streak: streak card, 14-day chart, top topics
- [x] **NEW** Siri Shortcuts via App Intents (open latest, listen aloud, open watchlist)
- [x] Reviewer notes prepared: see `APP_REVIEW_NOTES.md`
- [ ] In Xcode → Target → Signing & Capabilities, ensure "Background Modes" is added with **Audio, AirPlay, and Picture in Picture** + **Background fetch** checked
- [ ] Validate reviewer test path on physical device before submission

### Screenshots Needed
1. Login screen with logo
2. Home feed with articles
3. Article detail view
4. Search results
5. Saved articles
6. Settings screen
7. iPad sidebar view

## Architecture

### Services
- **ArticleService**: Protocol for fetching articles
- **GhostArticleService**: Implementation for Ghost CMS
- **MockArticleService**: For testing/previews
- **AuthenticationManager**: Handles all auth flows
- **AnalyticsManager**: Firebase Analytics
- **NotificationManager**: Push notifications
- **OfflineManager**: Local caching and offline support
- **BackgroundRefreshManager**: Background updates
- **SpotlightIndexer**: iOS Spotlight integration
- **CryptoMarketService** *(new)*: CoinGecko public market data client
- **CryptoMarketViewModel** *(new)*: Watchlist state, ordering, auto-refresh
- **AudioReaderManager** *(new)*: AVSpeechSynthesizer-backed Listen Mode (background audio)
- **HighlightsManager** *(new)*: On-device highlights and notes store
- **ReadingStatsManager** *(new)*: Streaks, totals, top topics, 14-day history

### Views
- **LoginView**: Authentication screen
- **HomeFeedView**: Main article feed
- **ArticleDetailView**: Full article view (now with inline `AudioPlayerControls` and a highlight toolbar button)
- **DiscoverView**: Search and explore
- **SavedArticlesView**: Bookmarked articles
- **SettingsView**: App settings
- **ProfileSettingsView**: User profile (now links to Reading Stats and Highlights)
- **AuthorProfileView**: Author details
- **AdaptiveContentView**: 5-tab iPhone layout / iPad sidebar (Home, Markets, Search, Saved, Profile)
- **CryptoWatchlistView** *(new)*: Markets tab — list, add, reorder, swipe-to-remove
- **AddCoinSearchView** *(new)*: Search any coin to add to watchlist
- **CoinDetailView** *(new)*: Coin detail with sparkline and stat grid
- **AudioPlayerControls** *(new)*: Inline article audio bar
- **AddHighlightSheet** *(new)*: Save passage + note + color
- **HighlightsView** *(new)*: Browse, filter and search highlights
- **ReadingStatsView** *(new)*: Streak card, 14-day chart, top topics

### App Intents *(new)*
- `OpenLatestArticleIntent`
- `OpenCryptoWatchlistIntent`
- `ReadLatestArticleIntent`
- Wired in `EtherworldShortcutsProvider` and observed by `AdaptiveContentView`.

### Data Models
- **Article**: Main content model
- **Author**: Writer information
- **User**: Account data
- **Coin** / **SparklineData** / **CoinSearchResult** *(new)*: CoinGecko market models
- **ArticleHighlight** / **HighlightColor** *(new)*: User highlights
- **ReadingDayLog** *(new)*: Per-day reading totals

## Backend Services

### Ghost CMS
- Content delivery
- Article management
- Tag/category filtering
- Multi-language support

### Supabase
- Email logging (`emails` table)
- User preferences sync (`user_preferences` table)
- Backup/restore data

### Firebase
- Authentication (Apple, Google, Email)
- Analytics
- Cloud Messaging (push notifications)
- Crashlytics (optional)

### CoinGecko *(new — Markets tab)*
- Live cryptocurrency price + sparkline data via the public `/coins/markets` and `/search` endpoints
- No API key required
- 60-second auto-refresh; pull-to-refresh supported
- Rate limit: ~10–30 req/min on the free public tier — well within app usage

## Build Instructions

1. Open `IOS_App.xcodeproj` in Xcode
2. Select your development team
3. Ensure all config files are present
4. Build and run on simulator or device

### Archive for App Store
1. Select "Any iOS Device" as destination
2. Product → Archive
3. Validate the archive
4. Distribute to App Store Connect
5. Submit for review

## Development Notes

- Test all auth flows on physical device before submission
- Verify Firebase and Supabase are properly configured
- Check that all API keys are valid and not expired
- Ensure offline mode works correctly
- Test on both iPhone and iPad

## Support

- Website: https://etherworld.co
- Twitter: https://twitter.com/AayushS20298601
- Privacy Policy: https://etherworld.co/privacy

## License

Proprietary - All rights reserved
