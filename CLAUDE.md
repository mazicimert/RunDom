# RunDom – iOS Project Guide

## Project Overview

RunDom (user-facing brand: **Runpire**) is a gamified running app where users conquer real-world territories on a map by running through them. It is NOT a fitness tracker — it's a competitive, territory-based game that uses GPS running as its core mechanic.

> **Branding note:** The Xcode project, bundle ID, and source folder are named `RunDom`, but the app's display name and all user-facing copy use **Runpire**. Keep codebase identifiers as `RunDom`; only surface `Runpire` in localized strings, splash, share cards, and brand chrome.

> **Currency naming:** The in-game currency is called **Points** (English) / **Puan** (Turkish) in all user-facing copy. Internal code identifiers still use `trail` (e.g. `totalTrail`, `TrailCalculator`, `currentSeasonTrail`, `run.trailEarned` localization key). Don't rename code symbols — only the localized strings say "Points / Puan".

**Core loop:** Run → Conquer territories → Earn Points → Compete on leaderboards → Defend your zones

## Tech Stack

- **Language:** Swift (SwiftUI)
- **Min Deployment Target:** iOS 17.0 (Xcode project) — note: B (Privacy Zones) uses iOS 17+ Map API (`MapCameraPosition`, `MapCircle`, `onMapCameraChange`); lowering below iOS 17 requires rewriting `AddPrivacyZoneView` with an MKMapView wrapper
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
| Cloud Firestore | User profiles, badges, leaderboards, run history, territory loss events |
| Realtime Database | Live territory changes (URL: `https://rundom-e7aad-default-rtdb.europe-west1.firebasedatabase.app`) |
| Cloud Functions (Node.js) | Anti-cheat, point calculation, weekly season reset |
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
│   ├── Models/                    # Codable/Identifiable structs (User, RunSession, Territory, PlayerLevel, …)
│   ├── Components/                # Reusable UI (Lottie, ShareSheet, buttons, cards, image cache)
│   ├── Extensions/                # String+Localization, Color+Theme, Color+Hex, Date, Double, H3, MKPolygon, View
│   ├── Utilities/                 # Constants, Logger, Haptics, AppGroup
│   ├── Localization/              # en.lproj + tr.lproj Localizable.strings
│   ├── Resources/Lottie/          # Animation JSON files
│   ├── Services/
│   │   ├── Firebase/              # Auth, Firestore, RealtimeDB, Storage, RemoteConfig, Analytics, Crashlytics, Messaging
│   │   ├── Game/                  # TrailCalculator, Territory, TerritoryLoss, Streak, Season, AntiCheat, Badge, DailyChallenge
│   │   ├── H3/                    # H3GridService
│   │   ├── Location/              # LocationManager
│   │   ├── Motion/                # MotionManager
│   │   ├── Run/                   # RunAudioService (AVSpeechSynthesizer kilometer announcer)
│   │   ├── Localization/          # LocalizationManager (runtime language), UnitPreference (km / mi)
│   │   ├── Geocoding/             # GeocodingService (CLGeocoder + cache)
│   │   ├── Notification/          # NotificationService (FCM + local + deep linking)
│   │   ├── Offline/               # OfflineStorageService (CoreData), SyncService (NWPathMonitor)
│   │   └── Widget/                # WidgetDataService (App Group write-through + WidgetCenter reload)
│   └── Features/
│       ├── Onboarding/            # Splash, Welcome, slides, permissions, auth, profile completion
│       ├── Map/                   # Territory overlays, detail sheets, CellInspectorBar
│       ├── Run/                   # PreRun, ActiveRun, PostRun, share card, gallery, review sheet
│       ├── Profile/               # Avatar, badges, level breakdown, settings, edit profile
│       ├── Leaderboard/           # Global/neighborhood rankings
│       └── Stats/                 # Run history, charts, weekly reports, calendar heatmap
└── RunDomWidget/                  # Widget extension target
    ├── RunDomWidgetBundle.swift   # @main bundle (WeeklySummary + ActivityHeatmap)
    ├── RunDomWidget.swift         # Weekly summary widget
    ├── ActivityHeatmapWidget.swift# 84-day activity heatmap widget
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
- Supported languages: Turkish (`tr`), English (`en`)
- Device language = Turkish → app in Turkish; all others → English
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

## Run Voice Feedback

- `RunAudioService` (singleton, `AVSpeechSynthesizer`) announces each kilometer with current pace.
- Toggle: `AppConstants.UserDefaultsKeys.voiceFeedbackEnabled` (default ON).
- Localizes voice + spoken text by `LocalizationManager.selectedLanguageCode` (Turkish vs English).
- Respects `UnitPreference.useMiles` to announce miles instead of kilometres when enabled.

## Run Gallery & Share Cards

- `RunGalleryMapSnapshotter` renders the run's polyline on a `MKMapSnapshotter` snapshot.
- `RunGalleryPhotoLibrarySaver` saves to the user's photo library (requires `NSPhotoLibraryAddUsageDescription`).
- `RunSummaryShareRenderer` + `PostRunShareCardView` produce a branded share image (Runpire watermark).
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

- Bottom Tab Bar: Map | Run (center, large button) | Profile | Leaderboard | Stats
- Tab bar always visible except during active run
- Run screen opens as full-screen modal
- Gesture-based navigation preferred over back buttons
- Animations under 0.3s
- Empty state designs for every screen

### Stats Screen
- Past runs list + per-run detail (distance, duration, Points, territories)
- Weekly/monthly summary charts (`ChartView`)
- 84-day calendar heatmap (`RunCalendarHeatmapView` + `CalendarHeatmapCell` + `CalendarHeatmapViewModel`) — same data backing the widget

## Onboarding Flow

1. Splash Screen (logo + Lottie animation, "Runpire" wordmark)
2. Welcome screen (`WelcomeView`)
3. 3 onboarding slides (full-screen, bold typography, mock images)
4. Location permission screen (Always On with explanation)
5. Notification permission screen
6. Sign Up / Sign In (Apple required, Google optional)
7. Complete Profile (if display name missing from Apple Sign In)
- Only shown on first launch (UserDefaults flag)

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

- App brand is **Runpire** in user-facing copy; project + bundle keep the `RunDom` name.
- `FirebaseApp.configure()` is called in `AppDelegate` via `@UIApplicationDelegateAdaptor`
- H3 grid uses custom pseudo-H3 coordinate quantization (not Uber's C library)
- Territory sync uses Realtime Database transactions to prevent race conditions
- Remote Config for all tunable game parameters (speed thresholds, multipliers, zone sizes)
- All game parameters should be server-configurable without app updates
- Every user model includes `isPremium: Bool = true` (everyone gets true for now, StoreKit deferred)
- Offline mode uses programmatic CoreData model (no `.xcdatamodeld` file)
- Lottie animations bundled: `Running_character.json`, `Streak_fire.json`, `Unlocked.json`, `confetti.json`, `run_countdown.json`, `level_up.json`
- Widgets read from App Group `UserDefaults`; always go through `WidgetDataService` so timelines reload.

## Development Roadmap

17-step implementation plan ordered by dependency chain. Steps 1–17 are complete; the project has since added widgets, share cards, run gallery, voice feedback, unit preferences, level breakdown, territory loss flow, and daily challenge selection on top of the original plan.

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
- `Localization/en.lproj/Localizable.strings`
- `Localization/tr.lproj/Localizable.strings`
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

### Step 4: App Shell & Navigation ✅
> Tab bar, routing, global state

- `App/AppState.swift` — ObservableObject: isAuthenticated, isOnboardingComplete, currentUser
- `App/AppRouter.swift` — NavigationPath, sheet management
- `App/MainTabView.swift` — Bottom Tab Bar: Map | Run (center) | Profile | Leaderboard | Stats
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

- `Features/Onboarding/Views/SplashView.swift` — Logo + Lottie animation, Runpire wordmark
- `Features/Onboarding/Views/WelcomeView.swift` — Post-splash welcome screen
- `Features/Onboarding/Views/OnboardingPageView.swift` — Single slide (reusable)
- `Features/Onboarding/Views/OnboardingContainerView.swift` — 3-slide TabView pager
- `Features/Onboarding/Views/PermissionRequestView.swift` — Location + notification permissions
- `Features/Onboarding/Views/AuthView.swift` — Apple Sign In + Google Sign In (Runpire branded)
- `Features/Onboarding/Views/CompleteProfileView.swift` — Post-auth display name completion
- `Features/Onboarding/ViewModels/OnboardingViewModel.swift` — Page state, UserDefaults flag
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
- `Features/Run/RunGalleryMapSnapshotter.swift` — `MKMapSnapshotter` route renderer
- `Features/Run/RunGalleryPhotoLibrarySaver.swift` — Photos library saver
- `Features/Run/RunSummaryShareRenderer.swift` — Image renderer for share card
- `Features/Run/ViewModels/PreRunViewModel.swift` — Mode selection state
- `Features/Run/ViewModels/ActiveRunViewModel.swift` — Timer, distance, speed, GPS stream, territory capture
- `Features/Run/ViewModels/PostRunViewModel.swift` — Points calculation, save to Firebase, widget refresh
- `Services/Run/RunAudioService.swift` — Kilometer voice announcements (AVSpeechSynthesizer)

### Step 12: Profile Screen ✅
> User info, avatar, badges, level

- `Features/Profile/Views/ProfileTabView.swift` — Avatar, name, total Points, streak, level, badges
- `Features/Profile/Views/AvatarView.swift` — Static placeholder
- `Features/Profile/Views/LevelBreakdownView.swift` — Level + progress to next level
- `Features/Profile/Views/BadgeGridView.swift` — Badge grid
- `Features/Profile/Views/BadgeDetailView.swift` — Badge detail
- `Features/Profile/Views/SettingsView.swift` — Language, units, voice feedback, notifications, sign out, about
- `Features/Profile/Views/EditProfileView.swift` — Name, photo editing
- `Features/Profile/ViewModels/ProfileViewModel.swift` — User data, badge loading, level calc
- `Features/Profile/ViewModels/BadgeViewModel.swift` — Badge unlock, progress
- `Features/Profile/ViewModels/SettingsViewModel.swift` — Sign out, notification toggle, unit toggle

### Step 13: Leaderboard Screen ✅
> Rankings and competition

- `Features/Leaderboard/Views/LeaderboardTabView.swift` — Global / Neighborhood segment
- `Features/Leaderboard/Views/LeaderboardListView.swift` — Ranked list with podium top-3
- `Features/Leaderboard/Views/LeaderboardRowView.swift` — Single row: rank, avatar, name, Points
- `Features/Leaderboard/ViewModels/LeaderboardViewModel.swift` — Fetch rankings, season filter

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

### Step 15: Notifications ✅
> Push notification system

- `Services/Notification/NotificationService.swift` — FCM + local notification
- `Services/Geocoding/GeocodingService.swift` — Coordinate → neighborhood name

### Step 16: Offline Mode & Sync ✅
> Offline support

- `Services/Offline/OfflineStorageService.swift` — Programmatic CoreData model, save/load (no .xcdatamodeld file)
- `Services/Offline/SyncService.swift` — NWPathMonitor, auto-sync on reconnect, retry up to 5 times

### Step 17: Polish & Release Prep ⏳
> Final touches

- ~~Empty state designs for all screens~~ ✅
- ~~Lottie animations (splash, run start/complete, territory captured, level up)~~ ✅
- ~~Haptic feedback~~ ✅
- ~~App icon design~~ ✅
- ~~Complete all localization strings~~ ✅
- ~~Info.plist permission descriptions~~ ✅
- ~~Widgets (weekly summary + activity heatmap)~~ ✅
- ~~Branded share cards + run gallery~~ ✅
- ~~Voice feedback per kilometer~~ ✅
- ~~Imperial unit support (km / mi)~~ ✅
- ~~Player level system~~ ✅
- Accessibility audit (VoiceOver, Dynamic Type)
- Performance and memory optimizations

### Dependency Table

| Step | Area | Depends On |
|------|------|-----------|
| 1 | Foundation | — |
| 2 | Data Models | Step 1 |
| 3 | Firebase & Auth | Step 2 |
| 4 | App Shell & Nav | Step 3 |
| 5 | UI Components | Step 1 |
| 6 | Onboarding & Auth Flow | Steps 3, 4, 5 |
| 7 | Location & Motion | Step 1 |
| 8 | H3 Grid | Step 7 |
| 9 | Map Screen | Steps 4, 8 |
| 10 | Game Services | Steps 2, 3, 8 |
| 11 | Run Feature ⭐ | Steps 7, 8, 9, 10 |
| 12 | Profile | Steps 3, 4, 5 |
| 13 | Leaderboard | Steps 3, 4 |
| 14 | Stats | Steps 3, 4, 11 |
| 15 | Notifications | Step 3 |
| 16 | Offline Mode | Step 11 |
| 17 | Polish & Release | All |
