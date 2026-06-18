# EtherWorld App Store Metadata

## App Name
EtherWorld by Avarch

## Subtitle
Web3 & Tech News

## App Store General Information
- **Bundle ID:** co.etherworld.app
- **SKU:** co.etherworld.app
- **Apple ID:** 6759963170
- **Primary Language:** English (U.S.)
- **Category:** News, Education
- **Content Rights:** No, this app does not contain, show, or access third-party content.
- **License Agreement:** Apple's Standard License Agreement

## Promotional Text
Track crypto prices in your native watchlist, listen to articles in the background, save highlights and notes, and keep a daily reading streak — all in one focused iPhone and iPad app.

## Description
EtherWorld is a native iOS app for crypto and blockchain readers and traders. It combines a focused reading experience with a real-time markets tracker, listen mode, personal highlights, and reading insights — all powered by native iOS frameworks.

Markets — track the prices of any cryptocurrency in a customizable watchlist. See 7-day sparkline charts, 24-hour change, market cap, and volume. Live data refreshes automatically every minute.

Listen mode — every article can be read aloud using on-device speech synthesis with adjustable speed and full background audio support. Lock the screen and keep listening.

Highlights & notes — save your favorite passages from any article with five highlight colors and personal notes. Search and filter your highlights in a dedicated hub.

Reading stats & streak — keep a daily reading streak, see your top topics, total minutes read, and a 14-day reading chart. All computed on-device.

For You feed — pick the topics you care about and get a personalized ranking, or switch to Latest at any time.

Other native features:
- Apple, Google, and email OTP sign-in
- Save articles for offline reading and reading later
- Author profiles and shareable article links
- Search across articles, tags, and authors
- Background refresh for fresh content
- Push notification preferences and quiet hours
- iPad-optimized layout with a sidebar
- Siri shortcuts to open the latest article, listen aloud, or open your watchlist
- Privacy policy, data export, and full account controls
- Spotlight indexing of articles for system-wide search

EtherWorld uses Ghost CMS as a content source for articles and CoinGecko for live market data, but the app provides native reading tools, offline support, search, personalization, listen mode, highlights, reading stats, and live markets that go far beyond a web browsing experience.

## Keywords
crypto, blockchain, bitcoin, ethereum, prices, watchlist, news, articles, web3, defi, nft, markets, reader, offline, listen, highlights, streak, personalization

## Support URL
https://etherworld.co

## Privacy Policy URL
https://etherworld.co/privacy

## Reviewer Notes
See APP_REVIEW_NOTES.md for the full reviewer test path.

Quick summary:
1. Launch and sign in.
2. Complete personalization onboarding.
3. Tap the Markets tab and confirm live prices, watchlist add / remove / reorder.
4. Open any article, use Listen mode, lock the screen to confirm background audio.
5. Tap the highlighter icon to save a passage with a note.
6. Open Profile → Reading Stats & Streak and Highlights & Notes.
7. Confirm Siri shortcuts ("Read me the latest EtherWorld article", "Show my crypto watchlist in EtherWorld") are registered in iOS Settings.
8. Confirm internal article links stay in-app and external links open intentionally in Safari.

## Notes on Accuracy
- Markets data is sourced from CoinGecko's public API.
- Listen mode uses Apple's AVSpeechSynthesizer; it requires no network for synthesis.
- Highlights, notes, and reading stats are stored locally on device.
- Background audio capability is enabled via UIBackgroundModes.
- Do not mention camera, photo library, or Face ID permissions.
- Do not mention a demo login path.
- Do not describe session revocation as fully implemented; it is currently a session details UI.
