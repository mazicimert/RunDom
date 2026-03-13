import GoogleSignIn
import SwiftUI

@main
struct RunDomApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var appState = AppState()
    @StateObject private var router = AppRouter()
    @StateObject private var localizationManager = LocalizationManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(router)
                .environmentObject(localizationManager)
                .environment(\.locale, localizationManager.locale)
                .id(localizationManager.selectedLanguageCode)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
