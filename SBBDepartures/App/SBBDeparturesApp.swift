import SwiftUI

@main
struct SBBDeparturesApp: App {
    @StateObject private var appState = DeparturesAppState()

    var body: some Scene {
        Window("SBB Departures", id: "management") {
            ManagementWindowView()
                .environmentObject(appState)
        }
        .windowToolbarStyle(.unified)

        MenuBarExtra {
            MenuBarPopoverView()
                .environmentObject(appState)
                .frame(width: 420)
        } label: {
            Label(appState.menuBarTitle, systemImage: "tram.fill")
        }
        .menuBarExtraStyle(.window)
    }
}
