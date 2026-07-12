# RunDom – iOS Project Guide

## Project Overview

RunDom (user-facing brand: **RunPire**) is a gamified running app where users conquer real-world territories on a map by running through them. It is NOT a fitness tracker — it's a competitive, territory-based game that uses GPS running as its core mechanic.

> **Branding note:** The Xcode project, bundle ID, and source folder are named `RunDom`, but the app's display name and all user-facing copy use **RunPire**. Keep codebase identifiers as `RunDom`; only surface `RunPire` in localized strings, splash, share cards, and brand chrome.

> **Currency naming:** The in-game currency is called **Points** (English) / **Puan** (Turkish) in all user-facing copy. Internal code identifiers still use `trail` (e.g. `totalTrail`, `TrailCalculator`, `currentSeasonTrail`, `run.trailEarned` localization key). Don't rename code symbols — only the localized strings say "Points / Puan".

**Core loop:** Run → Conquer territories → Earn Points → Compete on leaderboards → Defend your zones

## Tech Stack

- **Language:** Swift (SwiftUI)
- **Min Deployment Target:** iOS 17.0 (Xcode project) — note: Privacy Zones uses iOS 17+ Map API (`MapCameraPosition`, `MapCircle`, `onMapCameraChange`); lowering below iOS 17 requires rewriting `AddPrivacyZoneView` with an MKMapView wrapper
- **UI Framework:** SwiftUI
- **Maps:** MapKit (territory overlays, animations, snapshotter for share cards)
- **Location:** CoreLocation (real-time GPS, background tracking)
- **Motion:** CoreMotion (speed anomaly detection via accelerometer)
- **Audio:** AVFoundation (`AVSpeechSynthesizer` for kilometer voice feedback)
- **Photos:** PhotosUI / Photos (run gallery save, share card export)
- **Backend:** Firebase (project: `rundom-e7aad`)
- **Grid System:** H3 hexagonal indexing (Uber's geospatial system)
- **Animations:** Rive (avatar — deferred, use static placeholder), Lottie (UI animations)
- **Widgets:** WidgetKit (`RunDomWidget` extension — weekly summary + activity heatmap)
- **App Group:** `group.com.mertmazici.RunDom` (shares data with widget extension)
- **Package Manager:** Swift Package Manager (SPM)
- **HealthKit:** (optional) Step and calorie data integration

## SPM Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| [firebase-ios-sdk](https://github.com/firebase/firebase-ios-sdk) | 12.10.0+ | Auth, Firestore, Realtime DB, Storage, Messaging, Analytics, Crashlytics, Remote Config |
| [rive-ios](https://github.com/rive-app/rive-ios) | 6.15.2+ | Avatar animations (deferred — use placeholder for now) |
| [lottie-spm](https://github.com/airbnb/lottie-spm) | 4.6.0+ | UI animations |

## Firebase Services

| Service | Usage |
|---------|-------|
| Authentication | Apple Sign In (required), Google Sign In (optional) |
| Cloud Firestore | User profiles, badges, leaderboards, run history, territory loss events, social posts, follows, blocks |
| Realtime Database | Live territory changes (URL: `https://rundom-e7aad-default-rtdb.europe-west1.firebasedatabase.app`) |
| Cloud Functions (Node.js, europe-west1) | `deleteAccount`, `analyzeRun`, `analyzeWeek` |
| Cloud Messaging (FCM) | Push notifications |
| Storage | Profile photos, generated avatars |
| Remote Config | Game parameters (speed thresholds, multipliers, zone sizes) without app update |
| Analytics | User behavior tracking |
| Crashlytics | Crash reporting |

**Data split rule:** Realtime Database for live territory changes, Firestore for everything else.

## Project Structure

```
RunDom/
├── RunDom.xcodeproj/
├── RunDom/                        # Main app target
│   ├── Assets.xcassets/           # App icon, color sets, onboarding mocks, logo, welcome character
│   ├── GoogleService-Info.plist   # Firebase config
│   ├── Info.plist                 # Permissions configured
│   ├── RunDom.entitlements        # Sign in with Apple, APNs, Background Location, App Groups
│   ├── RunDomApp.swift            # @main entry, AppDelegate adaptor, environment injection
│   ├── ContentView.swift          # Onboarding state machine → MainTabView
│   ├── App/                       # AppDelegate, AppState, AppRouter, MainTabView, Territory loss prompt/bar/VM
│   ├── Models/                    # Codable/Identifiable structs (User, RunSession, Territory, PlayerLevel, Post, PrivacyZone, …)
│   ├── Components/                # Reusable UI (Lottie, ShareSheet, buttons, cards, image cache)
│   ├── Extensions/                # String+Localization, Color+Theme, Color+Hex, Date, Double, H3, MKPolygon, View
│   ├── Utilities/                 # Constants, Logger, Haptics, AppGroup
│   ├── Localization/              # en.lproj + tr.lproj + es.lproj + de.lproj + pt-BR.lproj Localizable.strings
│   ├── Resources/
│   │   ├── Lottie/                # Animation JSON files
│   │   ├── Legal/                 # Terms + community guidelines (en/tr .md files)
│   │   └── Video/                 # onboarding_run_loop.mp4 (hook screen background)
│   └── Services/
│       ├── Firebase/              # Auth, Firestore, RealtimeDB, Storage, RemoteConfig, Analytics, Crashlytics, Messaging,
│       │                          #   PostService, FeedService, FollowService, LikeService, CommentService,
│       │                          #   BlockService, ReportService, UserSearchService, PrivacyZoneService
│       ├── AI/                    # AIAnalysisService (Cloud Functions), TemplateInsightService (offline fallback)
│       ├── Game/                  # TrailCalculator, Territory, TerritoryLoss, Streak, Season, AntiCheat, Badge, DailyChallenge
│       ├── H3/                    # H3GridService
│       ├── Location/              # LocationManager
│       ├── Motion/                # MotionManager
│       ├── Run/                   # RunAudioService (AVSpeechSynthesizer kilometer announcer)
│       ├── Localization/          # LocalizationManager (runtime language), UnitPreference (km / mi)
│       ├── Geocoding/             # GeocodingService (CLGeocoder + cache)
│       ├── Notification/          # NotificationService (FCM + local + deep linking)
│       ├── Offline/               # OfflineStorageService (CoreData), SyncService (NWPathMonitor)
│       ├── Widget/                # WidgetDataService (App Group write-through + WidgetCenter reload)
│       ├── BlockedUsersStore.swift  # Global block-list cache (ObservableObject)
│       ├── HiddenContentStore.swift # Hidden posts/content cache (ObservableObject)
│       └── PrivacyZonesStore.swift  # User privacy zones cache (ObservableObject)
└── Features/
    ├── Onboarding/            # Splash, Hook (video), Pages (pager), Quiz, ColorReveal, LocationPriming, Auth, FirstMission, CompleteProfile
    ├── Map/                   # Territory overlays, detail sheets, CellInspectorBar
    ├── Social/                # Feed, PostCard, PostDetail, CreatePost, UserProfile, UserSearch, FollowList, Report
    ├── Run/                   # PreRun, ActiveRun, PostRun, share card, gallery, review sheet, daily challenge picker
    ├── Profile/               # Avatar, badges, level, settings, edit, privacy zones, blocked users, my posts
    ├── Stats/                 # Run history, charts, weekly reports, calendar heatmap
    ├── AIAnalysis/            # AI run/week analysis card + sheet + disclosure
    └── Legal/                 # LegalAcceptanceSheet, LegalDocumentView, LegalLink
└── RunDomWidget/              # Widget extension target
    ├── RunDomWidgetBundle.swift
    ├── RunDomWidget.swift          # Weekly summary widget
    ├── ActivityHeatmapWidget.swift # 84-day activity heatmap widget
    ├── Info.plist
    └── Assets.xcassets/
```

**Bundle ID:** `com.mertmazici.RunDom`
**Widget Bundle ID:** `com.mertmazici.RunDom.RunDomWidget`
**App Group:** `group.com.mertmazici.RunDom`

## Xcode Capabilities (Already Configured)

- Sign in with Apple ✅
- Push Notifications ✅
- Background Modes → Location updates ✅
- App Groups (main app + widget) ✅

## Info.plist Permissions (Already Configured)

- `NSLocationAlwaysAndWhenInUseUsageDescription`
- `NSLocationWhenInUseUsageDescription`
- `NSMotionUsageDescription`
- `NSPhotoLibraryAddUsageDescription` (run gallery / share card save)
- Google Sign-In URL scheme registered

## Architecture Guidelines

### Code Standards
- All code in Swift
- All comments in English
- SwiftUI for all UI
- Follow MVVM pattern
- Use Swift Concurrency (async/await) where applicable

### Localization
- Supported languages: English (`en`), Turkish (`tr`), Spanish (`es`), German (`de`), Brazilian Portuguese (`pt-BR`) — 5 languages, ~809 keys each
- Device language = Turkish → app in Turkish; all others → English (Spanish/German/pt-BR handled by the `en` fallback until language-specific overrides are added)
- Runtime language switching via `LocalizationManager` (ObservableObject)
- All strings via `Localizable.strings` — never hardcode user-facing text
- Currency unit (user-facing): "Puan" (tr) / "Points" (en) — keys: `trail.unit`, `trail.points`
- Avatar messages, notifications, badge names, weekly reports — all localized
- Date/time/number formats follow device locale

### Units (km / mi)
- `UnitPreference` (ObservableObject, singleton) toggles between metric and imperial.
- Stored in `UserDefaults` under `AppConstants.UserDefaultsKeys.unitPreference`.
- Helpers: `distanceValue`, `speedValue`, `paceValue`, plus localized `*UnitLabel` keys (`unit.distance.km` / `unit.distance.mi`, `unit.speed.kmh` / `unit.speed.mph`, `unit.pace.km` / `unit.pace.mi`).
- Internal calculations (Trail, anti-cheat, territory) always operate in metric — convert at the view layer only.

### Theme
- Support both Light and Dark mode
- All colors via SwiftUI `Color` system + Asset Catalog with per-theme definitions
- `Color+Hex` extension for hex-string colors stored on the user (territory paint color)
- Prefer system colors where possible

### Design Standards
- Follow Apple Human Interface Guidelines (HIG)
- Use SF Symbols for all icons
- Prefer native SwiftUI animations
- Smooth transitions (0.3s or less)
- Bold typography, high contrast
- Generous spacing and padding
- Every screen must have empty state design

## Game Systems

### Territory System
- Map divided into H3 hexagonal cells (resolution `9`, see `AppConstants.Location.h3Resolution`)
- Running through a cell conquers it (painted in user's color)
- Another user running same cell takes it over
- More distance in a cell = higher defense level = harder to capture
- 48 hours without running in a cell → defense level decays
- Anti-farming: low multiplier for running in small repeated areas
- When a user loses a cell, a `TerritoryLossEvent` is written to Firestore and surfaced via `TerritoryLossPromptSheet` / `TerritoryLossMapBrowserBar`

### Season System
- Weekly seasons, reset every Monday 00:00 UTC
- All territories reset at season start

### Points Formula
> User-facing label: "Points / Puan". Code identifier: `trail` (e.g. `TrailCalculator`, `totalTrail`).

```
Points = (Base × Speed × Duration × Zone) × Streak × Mode × Anti-Farm
```
- **Base:** distance(km) × 100
- **Speed multiplier:** min(avgSpeed / 10, 1.8) — min threshold 4 km/h (`Game.minSpeedKmh`), cap at 18 km/h
- **Duration multiplier:** min(1.0 + (minutes / 100), 2.0) — caps at 120 min
- **Zone multiplier:** min(1.0 + (newZones × 0.1), 2.0) — caps at 10+ new zones
- **Streak:** 3d→x1.2, 7d→x1.5, 14d→x2.0 — missing 1 day drops one tier (no full reset)
- **Mode:** Normal=x1.0 (guaranteed), Boost=x2.0 (drops to x1.0 if avg speed < 7 km/h)
- **Anti-Farm:** unique zones ratio >70%→x1.0, 40-70%→x0.7, <40%→x0.4
- **Caps:** Max 5,000 per run, 15,000 per day (constants still named `maxTrailPerRun` / `maxTrailPerDay`)

### Player Level System
- `PlayerLevel` (model) derives level from total accumulated Points.
- Threshold to reach level *N*: `250 · N · (N - 1)`. Gap between consecutive levels: `level · 500`.
- `LevelBreakdownView` (Profile) shows current level, progress to next, and span.
- Level-up celebration uses `level_up.json` Lottie.

### Boost Mode Speed Indicator
- Selection screen: show 7 km/h threshold clearly
- During run: live speed with color coding (green=safe, yellow=approaching, red=below threshold)
- Post-run: average vs threshold comparison, clear boost active/cancelled status

> **Removed: Dropzone System.** The dropzone feature has been retired from the product. The map no longer shows dropzone annotations and there is no spawn / claim flow. Some legacy code still lives in the repo (`Models/Dropzone.swift`, `Services/Game/DropzoneService.swift`, `Features/Map/Views/DropzoneAnnotationView.swift`, `Features/Map/Views/DropzoneDetailSheet.swift`, `dropzone*` keys in `AppRouter` / `MainTabView` / `MapViewModel`, plus `dropzone.*` localization keys) but it is dead — `MapTabView` now passes `dropzones: []` and `onDropzoneTapped: nil`. Treat it as removed when designing new features; clean up the leftovers when convenient.

### Daily Challenge System
- Daily rotating challenges with difficulty tiers (easy/medium/hard)
- Challenge types: distance, speed, territory, duration, zone variety
- Template-based with localized descriptions
- Bonus Points rewards based on difficulty
- Surfaced in `DailyChallengeSelectionView` before runs, progress tracked per run
- FCM topics per language (`daily_challenges_en`, `daily_challenges_tr`)

### Badge System
- 12 badges across categories: Performance, Territory, Exploration, Streak (the original Dropzone-tier badges are now legacy and not awarded)
- Rule-based auto-evaluation via `BadgeService` after each run
- Badge catalog seeded on first login
- Some badges are hidden/secret

### User Color
- Auto-assigned at registration — user cannot choose
- Used for territory painting on map and as widget accent

### User Model
- Include `isPremium: Bool = true` flag (everyone gets true for now)
- No StoreKit integration — monetization deferred

## Social System

### Feed
- Activity feed: fan-out writes (following feed) merged with public recent posts
- Hydrated via `FeedService` — `FeedViewModel` owns real-time listener
- `PostCardView` renders each post with lite-mode route map snapshot

### Posts
- Posts created from `CreatePostSheet` (run picker → composer) or from `PostShareComposerView` after a run
- Posts include: run reference, photos, visibility (public / followers-only), privacy-zone masking on route
- `PostService` handles CRUD; `LikeService` handles like toggles
- `PostShareCardView` renders sharable card image

### Social Graph
- Follow/unfollow via `FollowService`; `FollowListViewModel` backs followers/following lists
- Block/unblock via `BlockService`; global `BlockedUsersStore` caches blocked IDs
- `HiddenContentStore` tracks posts the user has hidden from their feed
- Report content/users via `ReportService` + `ReportReasonSheet`

### User Discovery
- `UserSearchService` — prefix-scan Firestore for username search
- `UserProfileView` + `UserProfileViewModel` — other user's public profile (follow/block actions)

### Leaderboard (inside Social tab)
- `SocialTabView` uses a segmented `SegmentedPill`-style control: **Feed** | **Leaderboard**
- Leaderboard is `LeaderboardTabView` (unchanged) embedded in the Social tab

## AI Analysis

- `AIAnalysisService` calls the `analyzeRun` and `analyzeWeek` Cloud Functions (europe-west1)
- `TemplateInsightService` provides deterministic fallback insights when the function call fails or user has no AI toggle
- `AIAnalysisCardView` embeds analysis teaser in PostRun / Stats; tapping opens `AIAnalysisSheetView`
- `AIDisclosureView` shows the AI disclosure before showing results for the first time
- User can toggle AI analysis in Settings (`AppConstants.UserDefaultsKeys.aiAnalysisEnabled`)

## Privacy Zones

- User-defined circular zones where GPS data is masked in posts and map overlays
- `PrivacyZone` model stored in Firestore (per-user subcollection) via `PrivacyZoneService`
- `PrivacyZonesStore` (global ObservableObject) caches the current user's zones
- `PrivacyZonesView` (Settings → Privacy) lists zones; `AddPrivacyZoneView` uses iOS 17 MapKit to place and size a new zone
- Post route preview (`RoutePreviewMap`) clips any route points inside the user's zones before rendering

## Legal Gate

- `LegalDocument` model describes in-app terms & community guidelines
- Legal documents bundled as Markdown in `Resources/Legal/` (en/tr for terms-of-use and community-guidelines)
- `LegalAcceptanceSheet` is presented the first time a user attempts to create a post (`CreatePostSheet`); acceptance is recorded to Firestore on the user document
- `LegalDocumentView` renders the Markdown document; `LegalLink` is a tappable link row

## Run Voice Feedback

- `RunAudioService` (singleton, `AVSpeechSynthesizer`) announces each kilometer with current pace.
- Toggle: `AppConstants.UserDefaultsKeys.voiceFeedbackEnabled` (default ON).
- Localizes voice + spoken text by `LocalizationManager.selectedLanguageCode` (Turkish vs English).
- Respects `UnitPreference.useMiles` to announce miles instead of kilometres when enabled.

## Run Gallery & Share Cards

- `RunGalleryMapSnapshotter` renders the run's polyline on a `MKMapSnapshotter` snapshot.
- `RunGalleryPhotoLibrarySaver` saves to the user's photo library (requires `NSPhotoLibraryAddUsageDescription`).
- `RunSummaryShareRenderer` + `PostRunShareCardView` produce a branded share image (RunPire watermark).
- `RunGalleryView` lists past run snapshots; `RunReviewSheet` collects rating/notes after a run.
- `ShareSheet` is the SwiftUI wrapper for `UIActivityViewController`.

## Widgets (RunDomWidget extension)

Two widgets, both reading from the App Group `UserDefaults`:

| Widget | Data model | UserDefaults key |
|--------|------------|------------------|
| `RunDomWidget` (weekly summary) | `WeeklySummary` (totalTrail [= weekly Points], totalDistanceMeters, runCount, streakDays, userColorHex) | `AppGroup.weeklySummaryKey` ("weeklySummary") |
| `ActivityHeatmapWidget` (84-day grid) | `HeatmapWidgetData` (intensities `[Int]` of length 84, userColorHex) | `AppGroup.heatmapDataKey` ("heatmapData") |

- `WidgetDataService.shared` (main app, `@MainActor`) writes JSON-encoded payloads after each run / data change and calls `WidgetCenter.shared.reloadAllTimelines()`.
- Widget code reads via `UserDefaults(suiteName: AppGroup.identifier)`.
- App Group identifier: `group.com.mertmazici.RunDom` — both targets must have the App Groups capability enabled.

## Navigation

- Bottom Tab Bar: **Map** | **Social** (Feed + Leaderboard segmented) | **Run** (center, large button) | **Stats** | **Profile**
- Tab bar always visible except during active run
- Run screen opens as full-screen modal
- Gesture-based navigation preferred over back buttons
- Animations under 0.3s
- Empty state designs for every screen

### Stats Screen
- Past runs list + per-run detail (distance, duration, Points, territories)
- Weekly/monthly summary charts (`ChartView`)
- 84-day calendar heatmap (`RunCalendarHeatmapView` + `CalendarHeatmapCell` + `CalendarHeatmapViewModel`) — same data backing the widget
- `WeeklyReportView` — weekly summary with route art + share

## Onboarding Flow

1. **Splash** (`SplashView`) — logo + Lottie animation, "RunPire" wordmark
2. **Hook** (`HookView`) — full-screen looping video (`onboarding_run_loop.mp4` in `Resources/Video/`) with strong value prop copy
3. **Pages** (`OnboardingContainerView`) — 3-slide pager (mock screenshots: `onboarding_map_overview`, `onboarding_attack_notification`, `onboarding_feed`, `onboarding_map_detail`, `onboarding_leaderboard`)
4. **Quiz** (`QuizContainerView`) — 4 personalization questions: weekly goal / motivation / experience / preferred mode (answers stored in `RunnerProfile` / `pendingProfile` on `OnboardingViewModel`)
5. **ColorReveal** (`ColorRevealView`) — animated reveal of the user's assigned territory color
6. **LocationPermission** (`LocationPrimingView`) — foreground location ask with explanation
7. **Auth** (`AuthView`) — Apple Sign In (required) + Google Sign In (optional)
8. **CompleteProfile** (`CompleteProfileView`) — shown only if display name missing after sign-in; also FirstMission gateway on new accounts
- State machine driven by `OnboardingViewModel.Step` enum; persisted in UserDefaults via `AppState.isOnboardingComplete`

## Avatar System

- All users share the same avatar character (no custom selection)
- Avatar "talks" to user with personalized messages (emotional engagement)
- Rive integration deferred — use static placeholder image for now
- Future: AI-generated caricature avatars from user photos (Gemini API)

### Rive Details (For Future Implementation)
- State Machine: `Main Animation`
- Boolean inputs: `Talking Animation`, `Sad Animation`, `Happy Animation`

## Notifications (Push via FCM + Local)

- "Your territory was captured"
- "Defense level dropping"
- "Streak about to break" (local, calendar trigger at 20:00)
- "Daily challenge available"
- Post-run notification permission priming: `NotificationPostRunPromptSheet` shown after first run
- Deep-link destinations: map, territory detail, profile badges, stats, run history (`AppRouter` still defines a `dropzoneDetail` case — legacy, do not surface)

## Error Handling

- **GPS signal loss:** Run continues, warning shown. Gaps >60s excluded from calculations
- **Offline mode:** Run data stored in CoreData (programmatic model), auto-synced when online via `SyncService` (NWPathMonitor). Territory captures queued separately. Retry up to 5 times per item

## Anti-Cheat & Fairness

- Minimum speed threshold enforcement (`Game.minSpeedKmh = 4.0`)
- GPS anomaly detection (CoreMotion cross-validation)
- Small area farming detection → reduced multiplier
- Circular running in same location → low multiplier
- 48h inactivity → defense decay
- Firestore transactions / Realtime Database for race condition prevention

## Weekly Report

- Total distance, total Points, week-over-week % change
- Territories gained/lost
- Artistic route visualization on map
- Global and neighborhood leaderboards
- Shareable social media format (`PostRunShareCardView` + `RunSummaryShareRenderer`)

## Background Location

**Critical:** During runs, the app may be backgrounded.
- `allowsBackgroundLocationUpdates = true`
- `pausesLocationUpdatesAutomatically = false`
- App Store review requires justification for "Always On" location

## External APIs

| API | Purpose |
|-----|---------|
| Gemini API (Google) | AI caricature avatar generation (future) |
| CLGeocoder (Apple) | Coordinates → neighborhood names (cached in memory) |

## Important Notes

- App brand is **RunPire** in user-facing copy; project + bundle keep the `RunDom` name.
- `FirebaseApp.configure()` is called in `AppDelegate` via `@UIApplicationDelegateAdaptor`
- H3 grid uses custom pseudo-H3 coordinate quantization (not Uber's C library)
- Territory sync uses Realtime Database transactions to prevent race conditions
- Remote Config for all tunable game parameters (speed thresholds, multipliers, zone sizes)
- All game parameters should be server-configurable without app updates
- Every user model includes `isPremium: Bool = true` (everyone gets true for now, StoreKit deferred)
- Offline mode uses programmatic CoreData model (no `.xcdatamodeld` file)
- Lottie animations bundled: `Running_character.json`, `Streak_fire.json`, `Unlocked.json`, `confetti.json`, `run_countdown.json`, `level_up.json`, `loading.json`
- Widgets read from App Group `UserDefaults`; always go through `WidgetDataService` so timelines reload.
- `BlockedUsersStore` and `HiddenContentStore` are global `@EnvironmentObject` stores wired in `AppState` — inject at app root, not per-view.
- `PrivacyZonesStore` is similarly global; route masking in posts reads from it before rendering.

## Development Roadmap

All phases complete. The project is feature-complete; remaining work is polish/release prep.

### Step 1: Foundation ✅
> Shared infrastructure everything depends on

- `Utilities/Constants.swift` — UserDefaults keys, URLs, speed thresholds, caps, animation durations
- `Utilities/Logger.swift` — os.Logger wrapper
- `Utilities/Haptics.swift` — UIImpactFeedbackGenerator
- `Utilities/AppGroup.swift` — App Group identifier + widget UserDefaults keys
- `Extensions/String+Localization.swift` — `.localized` shorthand
- `Extensions/Color+Theme.swift` — `Color.territoryBlue`, `Color.boostGreen` etc.
- `Extensions/Color+Hex.swift` — Hex-string `Color` initializer (for stored user color)
- `Extensions/Date+Formatting.swift` — Locale-aware date formatting
- `Extensions/Double+Formatting.swift` — Distance, speed, Trail formatters
- `Extensions/View+Modifiers.swift` — Common view modifiers
- `Localization/{en,tr,es,de,pt-BR}.lproj/Localizable.strings` (5 languages)
- `Assets.xcassets/Colors/` — 7 color sets (BoostGreen, BoostRed, BoostYellow, CardBackground, SurfacePrimary, TerritoryBlue, TerritoryRed)
- `Services/Localization/LocalizationManager.swift` — Runtime language switcher
- `Services/Localization/UnitPreference.swift` — km / mi user preference

### Step 2: Data Models ✅
> Codable structs used by all features and services

- `Models/User.swift` — id, displayName, email, color, isPremium, streakDays, totalTrail (= total Points)
- `Models/RunSession.swift` — id, userId, startDate, endDate, distance, avgSpeed, trail (= Points earned), mode, route
- `Models/RoutePoint.swift` — latitude, longitude, timestamp, speed, altitude
- `Models/Territory.swift` — h3Index, ownerId, defenseLevel, lastRunDate, color
- `Models/TerritoryLossEvent.swift` — id, seasonId, h3Index, capturedAt, capturedByUserId, capturerDisplayName, isSeen
- `Models/Badge.swift` — id, name, description, iconName, category, isSecret, isUnlocked
- `Models/Dropzone.swift` — **legacy / unused** (dropzone feature removed)
- `Models/Season.swift` — id, startDate, endDate, weekNumber
- `Models/LeaderboardEntry.swift` — userId, displayName, trail (= Points), rank, neighborhood
- `Models/WeeklyReport.swift` — totalDistance, totalTrail, weekOverWeekChange, territories
- `Models/WeeklySummary.swift` — Lightweight widget payload (totalTrail [Points], distance, runs, streak, color)
- `Models/HeatmapWidgetData.swift` — 84-day intensity array + user color (widget payload)
- `Models/PlayerLevel.swift` — Level, current/next thresholds, fraction (computed from totalTrail)
- `Models/DailyChallenge.swift` — Templates, user progress, state, rewards
- `Models/Post.swift` — Social post (run ref, photos, visibility, likeCount, commentCount)
- `Models/Comment.swift` — Post comment (authorId, body, createdAt)
- `Models/FollowRelationship.swift` — follower/following uid pair
- `Models/BlockRelationship.swift` — blocker/blocked uid pair
- `Models/Report.swift` — content/user report (reason, reportedId, type)
- `Models/PrivacyZone.swift` — circular privacy zone (center, radiusMeters, label)
- `Models/LegalDocument.swift` — legal doc metadata (type, version, url)
- `Models/AIRunAnalysis.swift` — AI run analysis result (insights, suggestions)
- `Models/AIWeeklyAnalysis.swift` — AI weekly analysis result
- `Models/RunnerProfile.swift` — Quiz answer model (`WeeklyRunGoal`, `RunnerMotivation`, `RunnerExperience`, `preferredMode`)

### Step 3: Firebase Integration & Auth ✅
> Backend connection and user authentication

- `App/AppDelegate.swift` — `FirebaseApp.configure()`, FCM delegate
- `RunDomApp.swift` — AppDelegate connection (`@UIApplicationDelegateAdaptor`)
- `Services/Firebase/AuthService.swift` — Apple Sign In, Google Sign In, sign out, currentUser
- `Services/Firebase/FirestoreService.swift` — CRUD: users, runs, badges, leaderboards, loss events
- `Services/Firebase/RealtimeDBService.swift` — Territory read/write, listeners
- `Services/Firebase/StorageService.swift` — Profile photo upload/download
- `Services/Firebase/RemoteConfigService.swift` — Game parameters fetch
- `Services/Firebase/AnalyticsService.swift` — Event logging
- `Services/Firebase/CrashlyticsService.swift` — Non-fatal error logging
- `Services/Firebase/MessagingService.swift` — FCM token, topic subscriptions
- `Services/Firebase/PostService.swift` — Post CRUD
- `Services/Firebase/FeedService.swift` — Fan-out feed read (following + public)
- `Services/Firebase/LikeService.swift` — Like toggle
- `Services/Firebase/CommentService.swift` — Comment CRUD
- `Services/Firebase/FollowService.swift` — Follow/unfollow
- `Services/Firebase/BlockService.swift` — Block/unblock
- `Services/Firebase/ReportService.swift` — Content/user report submission
- `Services/Firebase/UserSearchService.swift` — Prefix-scan user search
- `Services/Firebase/PrivacyZoneService.swift` — Privacy zone CRUD
- `Services/BlockedUsersStore.swift` — Global block-list cache
- `Services/HiddenContentStore.swift` — Hidden content cache
- `Services/PrivacyZonesStore.swift` — Privacy zones cache

### Step 4: App Shell & Navigation ✅
> Tab bar, routing, global state

- `App/AppState.swift` — ObservableObject: isAuthenticated, isOnboardingComplete, currentUser, BlockedUsersStore, HiddenContentStore, PrivacyZonesStore
- `App/AppRouter.swift` — NavigationPath, sheet management
- `App/MainTabView.swift` — Bottom Tab Bar: **Map | Social | Run (center) | Stats | Profile**
- `App/TerritoryLossPromptSheet.swift` + `App/TerritoryLossPromptViewModel.swift` + `App/TerritoryLossMapBrowserBar.swift` — Cross-tab "you lost a cell" surfacing
- `ContentView.swift` — Onboarding/Auth check → MainTabView or OnboardingFlow

### Step 5: Shared UI Components ✅
> Reusable components before features

- `Components/LottieView.swift` — SwiftUI wrapper for Lottie
- `Components/RiveAvatarView.swift` — Static placeholder (Rive deferred)
- `Components/LoadingView.swift` — Loading spinner
- `Components/EmptyStateView.swift` — Icon + title + subtitle + CTA
- `Components/ErrorBannerView.swift` — Dismissable error banner
- `Components/PrimaryButtonStyle.swift` — Bold button style + `SecondaryButtonStyle`
- `Components/StatCardView.swift` — Icon + value + label card
- `Components/GradientBackground.swift` — Gradient modifier
- `Components/CachedImageView.swift` — Two-tier (memory + disk) image cache
- `Components/ShareSheet.swift` — `UIActivityViewController` SwiftUI wrapper

### Step 6: Onboarding & Auth Flow ✅
> First-time user experience

- `Features/Onboarding/Views/SplashView.swift` — Logo + Lottie animation, RunPire wordmark
- `Features/Onboarding/Views/HookView.swift` — Looping MP4 video (`onboarding_run_loop.mp4`) + value prop copy
- `Features/Onboarding/Views/OnboardingPageView.swift` — Single slide (reusable)
- `Features/Onboarding/Views/OnboardingContainerView.swift` — 3-slide TabView pager
- `Features/Onboarding/Views/QuizContainerView.swift` — 4-question personalization quiz
- `Features/Onboarding/Views/ColorRevealView.swift` — Animated territory color reveal
- `Features/Onboarding/Views/LocationPrimingView.swift` — Foreground location permission priming
- `Features/Onboarding/Views/AuthView.swift` — Apple Sign In + Google Sign In (RunPire branded)
- `Features/Onboarding/Views/FirstMissionView.swift` — First-run mission briefing (new accounts)
- `Features/Onboarding/Views/CompleteProfileView.swift` — Post-auth display name completion
- `Features/Onboarding/ViewModels/OnboardingViewModel.swift` — Step state machine, quiz answers (`RunnerProfile`), UserDefaults flag
- `Features/Onboarding/ViewModels/AuthViewModel.swift` — Sign-in flow, Firebase Auth

### Step 7: Location & Motion Services ✅
> Required infrastructure for Run feature

- `Services/Location/LocationManager.swift` — CLLocationManager, background tracking, Combine publisher
- `Services/Motion/MotionManager.swift` — CMMotionManager, accelerometer data
- `Extensions/CLLocationCoordinate2D+H3.swift` — Coordinate → H3 index helpers

### Step 8: H3 Grid System ✅
> Foundation for territory rendering on map

- `Services/H3/H3GridService.swift` — H3 index calculation, hex boundary polygon, neighbors
- `Extensions/MKPolygon+H3.swift` — Create MKPolygon from H3 hex boundary

### Step 9: Map Screen (Map Tab) ✅
> Display territories on map

- `Features/Map/Views/MapTabView.swift` — MapKit + territory overlays (passes empty dropzones list — feature removed)
- `Features/Map/Views/TerritoryOverlayView.swift` — H3 hex polygon rendering
- `Features/Map/Views/TerritoryDetailSheet.swift` — Territory detail sheet
- `Features/Map/Views/CellInspectorBar.swift` — Tap-a-cell inspector / quick info bar
- `Features/Map/Views/DropzoneAnnotationView.swift` — **legacy / unused** (dropzone removed)
- `Features/Map/Views/DropzoneDetailSheet.swift` — **legacy / unused** (dropzone removed)
- `Features/Map/ViewModels/MapViewModel.swift` — Region fetch, territory loading
- `Features/Map/ViewModels/TerritoryDetailViewModel.swift` — Single territory detail

### Step 10: Game Services (Game Logic) ✅
> Point calculation, streak, anti-cheat, territory

- `Services/Game/TrailCalculator.swift` — Full Points formula (class name kept as `TrailCalculator`)
- `Services/Game/TerritoryService.swift` — Territory capture, defense level, 48h decay
- `Services/Game/TerritoryLossService.swift` — Records loss events when another user takes a cell
- `Services/Game/StreakService.swift` — Tier calculation, grace period, tier drop
- `Services/Game/SeasonService.swift` — Weekly reset, active season info
- `Services/Game/AntiCheatService.swift` — GPS anomaly, farming detection, speed threshold
- `Services/Game/BadgeService.swift` — 12-badge catalog, auto-evaluation, seeding
- `Services/Game/DailyChallengeService.swift` — Daily rotation, selection, progress tracking
- `Services/Game/DropzoneService.swift` — **legacy / unused** (dropzone feature removed)

### Step 11: Run Feature ⭐ CORE ✅
> The heart of the app — active run tracking

- `Features/Run/Views/PreRunView.swift` — Normal/Boost mode selection
- `Features/Run/Views/DailyChallengeSelectionView.swift` — Pre-run challenge picker
- `Features/Run/Views/ActiveRunView.swift` — Full-screen: live map, stats, speed, pause/stop
- `Features/Run/Views/SpeedIndicatorView.swift` — Green/yellow/red color coding
- `Features/Run/Views/RunStatsOverlayView.swift` — Distance, duration, pace, Points (floating)
- `Features/Run/Views/PauseRunView.swift` — Pause overlay
- `Features/Run/Views/PostRunSummaryView.swift` — Summary: route, Points, territories, share
- `Features/Run/Views/PostRunShareCardView.swift` — Branded share card layout
- `Features/Run/Views/RunReviewSheet.swift` — Post-run rating / notes
- `Features/Run/Views/RunGalleryView.swift` — Saved run snapshots gallery
- `Features/Run/Views/NotificationPostRunPromptSheet.swift` — Post-run notification permission priming
- `Features/Run/RunGalleryMapSnapshotter.swift` — `MKMapSnapshotter` route renderer
- `Features/Run/RunGalleryPhotoLibrarySaver.swift` — Photos library saver
- `Features/Run/RunSummaryShareRenderer.swift` — Image renderer for share card
- `Features/Run/ViewModels/PreRunViewModel.swift` — Mode selection state
- `Features/Run/ViewModels/ActiveRunViewModel.swift` — Timer, distance, speed, GPS stream, territory capture
- `Features/Run/ViewModels/PostRunViewModel.swift` — Points calculation, save to Firebase, widget refresh
- `Services/Run/RunAudioService.swift` — Kilometer voice announcements (AVSpeechSynthesizer)

### Step 12: Profile Screen ✅
> User info, avatar, badges, level, settings, privacy

- `Features/Profile/Views/ProfileTabView.swift` — Avatar, name, total Points, streak, level, badges, my posts
- `Features/Profile/Views/AvatarView.swift` — Static placeholder
- `Features/Profile/Views/LevelBreakdownView.swift` — Level + progress to next level
- `Features/Profile/Views/BadgeGridView.swift` — Badge grid (summary)
- `Features/Profile/Views/AllBadgesView.swift` — Full badge collection screen
- `Features/Profile/Views/BadgeDetailView.swift` — Badge detail
- `Features/Profile/Views/SettingsView.swift` — Language, units, voice feedback, AI toggle, notifications, privacy zones, blocked users, delete account, sign out
- `Features/Profile/Views/EditProfileView.swift` — Name, photo editing
- `Features/Profile/Views/PrivacyZonesView.swift` — List + delete privacy zones
- `Features/Profile/Views/AddPrivacyZoneView.swift` — iOS 17 MapKit map to add a zone
- `Features/Profile/Views/BlockedUsersView.swift` — Manage blocked users
- `Features/Profile/Views/MyPostsListView.swift` + `ProfilePostRowView.swift` — User's own posts
- `Features/Profile/Views/DeleteAccountReauthSheet.swift` — Re-auth before account deletion
- `Features/Profile/ViewModels/ProfileViewModel.swift` — User data, badge loading, level calc
- `Features/Profile/ViewModels/BadgeViewModel.swift` — Badge unlock, progress
- `Features/Profile/ViewModels/SettingsViewModel.swift` — Sign out, notification toggle, unit toggle
- `Features/Profile/ViewModels/MyPostsViewModel.swift` — User's post history

### Step 13: Social Screen ✅
> Feed, user discovery, leaderboard, social graph

- `Features/Social/Views/SocialTabView.swift` — Segmented: Feed | Leaderboard
- `Features/Social/Views/FeedView.swift` — Activity feed list
- `Features/Social/Views/PostCardView.swift` — Post card with lite-mode route map
- `Features/Social/Views/PostDetailView.swift` — Post detail + comments
- `Features/Social/Views/CreatePostSheet.swift` — Run picker → composer; gates on legal acceptance
- `Features/Social/Views/PostShareComposerView.swift` — Full post composer (text, photos, visibility)
- `Features/Social/Views/PostShareCardView.swift` — Shareable post card image
- `Features/Social/Views/SharePastRunPickerView.swift` — Pick a past run to share
- `Features/Social/Views/RoutePreviewMap.swift` — Route map in post (privacy-zone masked)
- `Features/Social/Views/UserProfileView.swift` — Other user's public profile
- `Features/Social/Views/UserSearchView.swift` — User search
- `Features/Social/Views/FollowListView.swift` — Followers / following list
- `Features/Social/Views/ReportReasonSheet.swift` — Report reason picker
- `Features/Social/ViewModels/FeedViewModel.swift`
- `Features/Social/ViewModels/PostDetailViewModel.swift`
- `Features/Social/ViewModels/UserProfileViewModel.swift`
- `Features/Social/ViewModels/UserSearchViewModel.swift`
- `Features/Social/ViewModels/FollowListViewModel.swift`
- `Features/Social/ViewModels/SharePastRunPickerViewModel.swift`

### Step 14: Stats Screen ✅
> Run history, charts, weekly report, calendar heatmap

- `Features/Stats/Views/StatsTabView.swift` — Weekly/monthly toggle, charts, heatmap
- `Features/Stats/Views/RunHistoryListView.swift` — Past runs list (distance, duration, Points)
- `Features/Stats/Views/RunHistoryDetailView.swift` — Single run detail
- `Features/Stats/Views/WeeklyReportView.swift` — Artistic route, comparison, share
- `Features/Stats/Views/ChartView.swift` — Swift Charts bar/line chart
- `Features/Stats/Views/RunCalendarHeatmapView.swift` + `CalendarHeatmapCell.swift` — 84-day heatmap
- `Features/Stats/ViewModels/StatsViewModel.swift` — Aggregate stats, chart data
- `Features/Stats/ViewModels/RunHistoryViewModel.swift` — Paginated run history
- `Features/Stats/ViewModels/WeeklyReportViewModel.swift` — Report generation, sharing
- `Features/Stats/ViewModels/CalendarHeatmapViewModel.swift` — Heatmap intensity computation

### Step 15: AI Analysis ✅
> Per-run and weekly AI insights

- `Services/AI/AIAnalysisService.swift` — `analyzeRun` / `analyzeWeek` Cloud Function calls
- `Services/AI/TemplateInsightService.swift` — Deterministic fallback insights
- `Features/AIAnalysis/Views/AIAnalysisCardView.swift` — Summary card embedded in PostRun/Stats
- `Features/AIAnalysis/Views/AIAnalysisSheetView.swift` — Full analysis sheet
- `Features/AIAnalysis/Views/AIDisclosureView.swift` — One-time AI disclosure
- `Features/AIAnalysis/ViewModels/AIAnalysisViewModel.swift`

### Step 16: Privacy Zones ✅
> User-defined GPS masking zones

- `Models/PrivacyZone.swift`
- `Services/Firebase/PrivacyZoneService.swift`
- `Services/PrivacyZonesStore.swift`
- `Features/Profile/Views/PrivacyZonesView.swift`
- `Features/Profile/Views/AddPrivacyZoneView.swift` — iOS 17 MapKit (`MapCameraPosition`, `MapCircle`, `onMapCameraChange`)

### Step 17: Legal Gate ✅
> Terms of Use + Community Guidelines acceptance

- `Models/LegalDocument.swift`
- `Features/Legal/LegalAcceptanceSheet.swift` — Shown before first post creation
- `Features/Legal/LegalDocumentView.swift`
- `Features/Legal/LegalLink.swift`
- `Resources/Legal/` — `terms-of-use-{en,tr}.md`, `community-guidelines-{en,tr}.md`

### Step 18: Notifications ✅
> Push notification system

- `Services/Notification/NotificationService.swift` — FCM + local notification
- `Services/Geocoding/GeocodingService.swift` — Coordinate → neighborhood name

### Step 19: Offline Mode & Sync ✅
> Offline support

- `Services/Offline/OfflineStorageService.swift` — Programmatic CoreData model, save/load (no .xcdatamodeld file)
- `Services/Offline/SyncService.swift` — NWPathMonitor, auto-sync on reconnect, retry up to 5 times

### Step 20: Polish & Release Prep ⏳
> Final touches

- ~~Empty state designs for all screens~~ ✅
- ~~Lottie animations (splash, run start/complete, territory captured, level up)~~ ✅
- ~~Haptic feedback~~ ✅
- ~~App icon design~~ ✅
- ~~Complete all localization strings (5 languages)~~ ✅
- ~~Info.plist permission descriptions~~ ✅
- ~~Widgets (weekly summary + activity heatmap)~~ ✅
- ~~Branded share cards + run gallery~~ ✅
- ~~Voice feedback per kilometer~~ ✅
- ~~Imperial unit support (km / mi)~~ ✅
- ~~Player level system~~ ✅
- ~~Social feed / follow / block~~ ✅
- ~~AI analysis (run + weekly)~~ ✅
- ~~Privacy zones~~ ✅
- ~~Legal gate~~ ✅
- Accessibility audit (VoiceOver, Dynamic Type)
- Performance and memory optimizations
- App Store submission prep
