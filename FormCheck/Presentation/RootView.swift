import SwiftUI

struct RootView: View {
    @StateObject private var auth = AuthManager()

    var body: some View {
        Group {
            if auth.isSignedIn {
                TabView {
                    HomeView()
                        .tabItem { Label("Home", systemImage: "house") }
                        .environmentObject(auth)
                    LibraryView()
                        .tabItem { Label("Library", systemImage: "film.stack") }
                    SettingsView()
                        .tabItem { Label("Settings", systemImage: "gearshape") }
                        .environmentObject(auth)
                }
                .toolbarBackground(.visible, for: .tabBar)
                .tint(Theme.accent)
            } else {
                AuthView()
                    .environmentObject(auth)
            }
        }
    }
}
