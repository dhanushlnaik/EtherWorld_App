# EtherWorld iOS App

A native iOS app for reading crypto and blockchain content from EtherWorld.

## App Details

- **Name**: EtherWorld
- **Bundle ID**: co.etherworld.app
- **Version**: 1.0 (Build 1)
- **Platform**: iOS 16.0+, iPadOS 16.0+

## Features

### Authentication
- ✅ Apple Sign In
- ✅ Google Sign In  
- ✅ OTP via Email (6-digit verification code)
- ✅ Firebase Authentication

### Core Features
- ✅ Browse articles from Ghost CMS
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

### Views
- **LoginView**: Authentication screen
- **HomeFeedView**: Main article feed
- **ArticleDetailView**: Full article view
- **DiscoverView**: Search and explore
- **SavedArticlesView**: Bookmarked articles
- **SettingsView**: App settings
- **ProfileSettingsView**: User profile
- **AuthorProfileView**: Author details

### Data Models
- **Article**: Main content model
- **Author**: Writer information
- **User**: Account data

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
