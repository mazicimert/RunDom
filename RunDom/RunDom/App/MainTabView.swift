import SwiftUI
import UserNotifications

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var router: AppRouter
    @Environment(\.scenePhase) private var scenePhase

    @State private var activeRunSession: RunSession?
    @State private var completedRunSession: RunSession?
    @StateObject private var territoryLossPromptViewModel = TerritoryLossPromptViewModel()
    @State private var showTerritoryLossPrompt = false
    @State private var showTerritoryLossMapBrowser = false
    @State private var skipTerritoryLossPromptDismissHandling = false

    var body: some View {
        ZStack {
            TabView(selection: $router.selectedTab) {
                // Map Tab
                NavigationStack {
                    MapTabView(locationManager: appState.locationManager)
                }
                .tabItem {
                    Label("tab.map".localized, systemImage: "map.fill")
                }
                .tag(AppRouter.Tab.map)

                // Leaderboard Tab
                NavigationStack {
                    LeaderboardTabView(locationManager: appState.locationManager)
                }
                .tabItem {
                    Label("tab.leaderboard".localized, systemImage: "trophy.fill")
                }
                .tag(AppRouter.Tab.leaderboard)

                // Run Tab (center)
                NavigationStack {
                    PreRunView(locationManager: appState.locationManager) { mode in
                        startRun(mode: mode)
                    }
                }
                .tabItem {
                    Label("tab.run".localized, systemImage: "figure.run")
                }
                .tag(AppRouter.Tab.run)

                // Stats Tab
                NavigationStack {
                    StatsTabView()
                }
                .tabItem {
                    Label("tab.stats".localized, systemImage: "chart.bar.fill")
                }
                .tag(AppRouter.Tab.stats)

                // Profile Tab
                NavigationStack {
                    ProfileTabView()
                }
                .tabItem {
                    Label("tab.profile".localized, systemImage: "person.fill")
                }
                .tag(AppRouter.Tab.profile)
            }

            // Full-screen active run overlay
            if router.isRunActive, let userId = appState.currentUser?.id,
               let userColor = appState.currentUser?.color {
                ActiveRunView(
                    viewModel: ActiveRunViewModel(
                        mode: activeRunSession?.mode ?? .normal,
                        userId: userId,
                        userColor: userColor,
                        userDisplayName: appState.currentUser?.displayName,
                        locationManager: appState.locationManager
                    ),
                    onFinish: { session in
                        completedRunSession = session
                        router.isRunActive = false
                    }
                )
                .transition(.move(edge: .bottom))
                .zIndex(1)
            }

            if shouldShowTerritoryLossMapBrowser {
                VStack {
                    Spacer()

                    TerritoryLossMapBrowserBar(
                        viewModel: territoryLossPromptViewModel,
                        onPrevious: {
                            territoryLossPromptViewModel.moveToPreviousEvent()
                            if let event = territoryLossPromptViewModel.selectedEvent {
                                router.focusMap(onTerritoryLoss: event.h3Index)
                            }
                        },
                        onNext: {
                            territoryLossPromptViewModel.moveToNextEvent()
                            if let event = territoryLossPromptViewModel.selectedEvent {
                                router.focusMap(onTerritoryLoss: event.h3Index)
                            }
                        },
                        onClose: {
                            closeTerritoryLossMapBrowser()
                        }
                    )
                    .padding(.horizontal, AppConstants.UI.screenPadding)
                    .padding(.bottom, 92)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .zIndex(2)
            }
        }
        .onChange(of: router.selectedTab) {
            Haptics.selection()
        }
        .sheet(item: $router.presentedSheet) { sheet in
            sheetContent(for: sheet)
        }
        .fullScreenCover(item: $completedRunSession) { session in
            PostRunSummaryView(session: session) {
                completedRunSession = nil
            }
            .environmentObject(appState)
            .environmentObject(router)
        }
        .sheet(isPresented: $showTerritoryLossPrompt, onDismiss: {
            Task { await dismissTerritoryLossPromptIfNeeded() }
        }) {
            TerritoryLossPromptSheet(
                viewModel: territoryLossPromptViewModel,
                onDismiss: {
                    showTerritoryLossPrompt = false
                },
                onShowOnMap: {
                    guard let event = territoryLossPromptViewModel.selectedEvent else { return }
                    skipTerritoryLossPromptDismissHandling = true
                    showTerritoryLossMapBrowser = true
                    router.focusMap(onTerritoryLoss: event.h3Index)
                    showTerritoryLossPrompt = false
                    Task { await territoryLossPromptViewModel.markBatchSeen() }
                },
                onPrevious: {
                    territoryLossPromptViewModel.moveToPreviousEvent()
                    if let event = territoryLossPromptViewModel.selectedEvent {
                        router.focusMap(onTerritoryLoss: event.h3Index)
                    }
                },
                onNext: {
                    territoryLossPromptViewModel.moveToNextEvent()
                    if let event = territoryLossPromptViewModel.selectedEvent {
                        router.focusMap(onTerritoryLoss: event.h3Index)
                    }
                }
            )
            .presentationDetents([.height(340)])
            .presentationDragIndicator(.visible)
        }
        .task(id: appState.currentUser?.id) {
            await refreshPromptQueue(initialLossEventId: consumePendingNotificationLossEventId())
        }
        .onReceive(NotificationCenter.default.publisher(for: .notificationTapped)) { notification in
            guard let destination = notification.userInfo?["destination"] as? NotificationDestination else { return }
            Task { await handleNotificationDestination(destination) }
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                UNUserNotificationCenter.current().setBadgeCount(0)
                Task { await refreshPromptQueue(initialLossEventId: consumePendingNotificationLossEventId()) }
            }
        }
        .onChange(of: router.isRunActive) {
            if !router.isRunActive {
                Task { await refreshPromptQueue() }
            }
        }
        .onChange(of: router.presentedSheet?.id) {
            if router.presentedSheet == nil {
                Task { await refreshPromptQueue() }
            }
        }
        .onChange(of: completedRunSession) {
            if completedRunSession == nil {
                Task { await refreshPromptQueue() }
            }
        }
    }

    // MARK: - Run Actions

    private func startRun(mode: RunMode) {
        activeRunSession = RunSession(
            id: UUID().uuidString,
            userId: appState.currentUser?.id ?? "",
            mode: mode,
            startDate: Date()
        )
        router.isRunActive = true
    }

    private var canPresentOverlayPrompts: Bool {
        !router.isRunActive
            && router.presentedSheet == nil
            && completedRunSession == nil
            && !showTerritoryLossMapBrowser
    }

    private var shouldShowTerritoryLossMapBrowser: Bool {
        showTerritoryLossMapBrowser
            && router.selectedTab == .map
            && !showTerritoryLossPrompt
            && router.presentedSheet == nil
            && !router.isRunActive
            && completedRunSession == nil
            && territoryLossPromptViewModel.hasEvents
    }

    private func consumePendingNotificationLossEventId() -> String? {
        guard let destination = NotificationService.shared.consumePendingDestination() else { return nil }
        router.handleNotificationDestination(destination)

        if case .territoryLossInbox(let initialLossEventId) = destination {
            return initialLossEventId
        }

        return nil
    }

    private func handleNotificationDestination(_ destination: NotificationDestination) async {
        _ = NotificationService.shared.consumePendingDestination()
        router.handleNotificationDestination(destination)

        switch destination {
        case .territoryLossInbox(let initialLossEventId):
            await refreshPromptQueue(initialLossEventId: initialLossEventId)
        default:
            await refreshPromptQueue()
        }
    }

    private func refreshPromptQueue(initialLossEventId: String? = nil) async {
        guard let userId = appState.currentUser?.id else { return }
        guard canPresentOverlayPrompts || showTerritoryLossPrompt else { return }

        if await territoryLossPromptViewModel.loadUnreadEvents(
            userId: userId,
            initialLossEventId: initialLossEventId
        ) {
            showTerritoryLossPrompt = true
            return
        }

        showTerritoryLossPrompt = false
    }

    private func dismissTerritoryLossPromptIfNeeded() async {
        if skipTerritoryLossPromptDismissHandling {
            skipTerritoryLossPromptDismissHandling = false
            return
        }

        guard territoryLossPromptViewModel.hasEvents else { return }
        showTerritoryLossMapBrowser = false
        await territoryLossPromptViewModel.markBatchSeenAndClear()
        await refreshPromptQueue()
    }

    private func closeTerritoryLossMapBrowser() {
        showTerritoryLossMapBrowser = false
        Task {
            await territoryLossPromptViewModel.markBatchSeen()
            territoryLossPromptViewModel.clear()
            await refreshPromptQueue()
        }
    }

    // MARK: - Sheet Content

    @ViewBuilder
    private func sheetContent(for sheet: AppRouter.Sheet) -> some View {
        switch sheet {
        case .runSession:
            Text("run.start".localized)
        case .postRunSummary:
            Text("run.summary".localized)
        case .territoryDetail:
            Text("map.myTerritory".localized)
        case .dropzoneDetail:
            Text("dropzone.active".localized)
        case .badgeDetail(let badge):
            BadgeDetailView(badge: badge)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        case .editProfile:
            EditProfileView()
                .environmentObject(appState)
        case .settings:
            SettingsView(authService: appState.authService)
                .environmentObject(appState)
        case .levelBreakdown(let totalTrail):
            LevelBreakdownView(totalTrail: totalTrail)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Preview

#Preview {
    MainTabView()
        .environmentObject(AppState())
        .environmentObject(AppRouter())
}
