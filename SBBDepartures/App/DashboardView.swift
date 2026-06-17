import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var appState: DeparturesAppState
    @State private var showingManage = false

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationTitle("Watchlists")
        } detail: {
            detail
                .navigationTitle(appState.activeProfile?.name ?? "Departures")
                .toolbar {
                    ToolbarItemGroup {
                        if appState.activeProfile?.mode == .automatic {
                            Button {
                                Task { await appState.refreshNearbyDepartures() }
                            } label: {
                                Label("Use Current Location", systemImage: "location")
                            }
                            .disabled(appState.isRefreshingNearby)
                            .accessibilityLabel("Use current location")
                        }

                        Button {
                            Task {
                                if appState.activeProfile?.mode == .automatic {
                                    await appState.refreshNearbyDepartures()
                                } else {
                                    await appState.refreshNow()
                                }
                            }
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        .disabled(appState.isRefreshing || appState.isRefreshingNearby)
                        .accessibilityLabel("Refresh departures")

                        Button {
                            showingManage = true
                        } label: {
                            Label("Manage Watchlists", systemImage: "slider.horizontal.3")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(SBBStyle.red)
                        .accessibilityLabel("Manage watchlists")
                    }
                }
        }
        .frame(minWidth: 880, minHeight: 620)
        .sheet(isPresented: $showingManage) {
            ManageSheetView()
                .environmentObject(appState)
                .frame(minWidth: 920, minHeight: 680)
        }
    }

    private var sidebar: some View {
        List(selection: activeProfileSelection) {
            Section("Watchlists") {
                ForEach(appState.state.profiles) { profile in
                    WatchlistSidebarRow(
                        profile: profile,
                        favoritesCount: appState.state.favorites.filter { $0.profileId == profile.id }.count
                    )
                    .tag(profile.id)
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            Button {
                showingManage = true
            } label: {
                Label("Manage Watchlists", systemImage: "slider.horizontal.3")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Manage watchlists")
            .padding()
        }
    }

    private var activeProfileSelection: Binding<UUID?> {
        Binding(
            get: { appState.state.activeProfileId },
            set: { id in
                guard let id,
                      let profile = appState.state.profiles.first(where: { $0.id == id }) else {
                    return
                }
                appState.setActiveProfile(profile)
            }
        )
    }

    private var detail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SBBBrandHeader(
                    title: appState.activeProfile?.name ?? "Departure board",
                    subtitle: subtitle
                )
                statusStrip
                departureBoard
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(SBBStyle.milk)
    }

    private var subtitle: String {
        if appState.activeProfile?.mode == .automatic {
            return "Nearby departures from your current location, ordered by time."
        }
        return "Next departures from saved favorites, ordered by time."
    }

    @ViewBuilder
    private var statusStrip: some View {
        if let error = appState.state.lastErrorMessage {
            Label(error, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(SBBStyle.redDark)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white, in: RoundedRectangle(cornerRadius: 8))
                .accessibilityLabel("Error: \(error)")
        } else if let last = appState.state.lastRefresh {
            HStack(spacing: 8) {
                if appState.isRefreshing || appState.isRefreshingNearby {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Refreshing")
                }
                Text("Updated \(DepartureDateFormatting.relativeFormatter.localizedString(for: last, relativeTo: Date()))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var departureBoard: some View {
        if appState.dashboardSnapshots.isEmpty {
            emptyState
        } else {
            VStack(spacing: 0) {
                DashboardHeaderRow()
                ForEach(appState.dashboardSnapshots) { snapshot in
                    DashboardDepartureRow(snapshot: snapshot)
                    Divider()
                }
            }
            .background(.white, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(SBBStyle.cloud)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "tram")
                .font(.system(size: 42))
                .foregroundStyle(SBBStyle.red)
                .accessibilityHidden(true)
            Text(appState.activeProfile?.mode == .automatic ? "No nearby departures yet" : "No saved departures for this watchlist")
                .font(.title3.weight(.semibold))
            Text(appState.activeProfile?.mode == .automatic ? "Use current location to load nearby trains, trams, and buses." : "Open Manage Watchlists, search for a stop, then add one or more line directions.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                Task {
                    if appState.activeProfile?.mode == .automatic {
                        await appState.refreshNearbyDepartures()
                    } else {
                        showingManage = true
                    }
                }
            } label: {
                Label(appState.activeProfile?.mode == .automatic ? "Use Current Location" : "Manage Watchlists", systemImage: appState.activeProfile?.mode == .automatic ? "location" : "plus")
            }
            .buttonStyle(.borderedProminent)
            .tint(SBBStyle.red)
            .accessibilityLabel(appState.activeProfile?.mode == .automatic ? "Use current location" : "Manage watchlists")
        }
        .frame(maxWidth: .infinity, minHeight: 280)
        .padding()
        .background(.white, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct WatchlistSidebarRow: View {
    var profile: LocationProfile
    var favoritesCount: Int

    var body: some View {
        HStack(spacing: 10) {
            Text(profile.displayEmoji)
                .font(.title3)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                    .lineLimit(1)
                Text(profile.mode == .automatic ? "Current location" : "\(favoritesCount) saved")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(profile.name), \(profile.mode == .automatic ? "current location" : "\(favoritesCount) saved departures")")
    }
}

struct DashboardHeaderRow: View {
    var body: some View {
        HStack {
            Text("In")
                .frame(width: 64, alignment: .trailing)
            Text("Line")
                .frame(width: 74, alignment: .leading)
            Text("Destination")
            Spacer()
            Text("Stop")
                .frame(width: 220, alignment: .leading)
            Text("Platform")
                .frame(width: 80, alignment: .trailing)
            Text("Time")
                .frame(width: 80, alignment: .trailing)
        }
        .font(.caption.weight(.bold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(SBBStyle.cloud.opacity(0.6))
        .accessibilityHidden(true)
    }
}

struct DashboardDepartureRow: View {
    var snapshot: DepartureSnapshot

    var body: some View {
        HStack(spacing: 14) {
            Text("\(DepartureLogic.minutesUntil(snapshot.effectiveDeparture))′")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(SBBStyle.red)
                .frame(width: 64, alignment: .trailing)

            LineBadge(text: snapshot.lineDisplay)
                .frame(width: 74, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text(snapshot.destination)
                    .font(.headline)
                    .foregroundStyle(SBBStyle.graphite)
                if let delay = snapshot.delayMinutes, delay > 0 {
                    Text("+\(delay) min delay")
                        .font(.caption)
                        .foregroundStyle(SBBStyle.redDark)
                }
            }

            Spacer()

            Text(snapshot.stopName)
                .lineLimit(1)
                .foregroundStyle(.secondary)
                .frame(width: 220, alignment: .leading)

            Text(snapshot.platform?.isEmpty == false ? snapshot.platform! : "—")
                .font(.headline.monospacedDigit())
                .frame(width: 80, alignment: .trailing)

            Text(DepartureDateFormatting.timeFormatter.string(from: snapshot.effectiveDeparture))
                .font(.headline.monospacedDigit())
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        var parts = [
            "\(snapshot.lineDisplay) to \(snapshot.destination)",
            "leaves in \(DepartureLogic.minutesUntil(snapshot.effectiveDeparture)) minutes",
            "from \(snapshot.stopName)",
            "at \(DepartureDateFormatting.timeFormatter.string(from: snapshot.effectiveDeparture))"
        ]
        if let platform = snapshot.platform, !platform.isEmpty {
            parts.append("platform \(platform)")
        }
        if let delay = snapshot.delayMinutes, delay > 0 {
            parts.append("\(delay) minutes delayed")
        }
        return parts.joined(separator: ", ")
    }
}
