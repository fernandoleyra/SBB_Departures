import SwiftUI

@main
struct SBBDeparturesApp: App {
    @StateObject private var appState = DeparturesAppState()

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .environmentObject(appState)
        }
        .windowToolbarStyle(.unified)

        MenuBarExtra {
            MenuBarPopoverView()
                .environmentObject(appState)
                .frame(width: 390)
        } label: {
            Label(appState.menuBarTitle, systemImage: "tram.fill")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(appState)
                .frame(minWidth: 680, minHeight: 520)
        }
    }
}
