import SwiftUI

struct MenuBarPopoverView: View {
    @EnvironmentObject private var appState: DeparturesAppState
    @Environment(\.openWindow) private var openWindow

    private var locationProfile: LocationProfile? {
        appState.state.profiles.first { $0.mode == .automatic }
    }

    // 1 row per unique line/direction — the soonest departure from nearbySnapshots.
    private var quickViewRows: [DepartureSnapshot] {
        var seen = Set<String>()
        return appState.nearbySnapshots
            .filter { $0.effectiveDeparture >= Date().addingTimeInterval(-60) }
            .sorted { $0.effectiveDeparture < $1.effectiveDeparture }
            .filter { seen.insert("\($0.lineDisplay)-\($0.destination)").inserted }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 420)
        .onAppear {
            if locationProfile != nil {
                Task { await appState.refreshNearbyDepartures() }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "location.fill")
                .foregroundStyle(SBBStyle.red)
                .font(.caption)
            Text(locationProfile?.name ?? "Quick View")
                .font(.headline)
            Spacer()
            if appState.isRefreshing || appState.isRefreshingNearby {
                ProgressView().controlSize(.small)
            } else {
                Button {
                    Task { await appState.refreshNearbyDepartures() }
                } label: {
                    Image(systemName: "arrow.clockwise").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Refresh departures")
            }
            if let last = appState.state.lastRefresh {
                Text(DepartureDateFormatting.relativeFormatter.localizedString(for: last, relativeTo: Date()))
                    .font(.caption2)
                    .foregroundStyle(
                        DepartureLogic.isStale(lastRefresh: appState.state.lastRefresh)
                            ? Color(hex: SBBPalette.orangeHex)
                            : .secondary
                    )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var content: some View {
        if appState.locationAuthorization == .denied || appState.locationAuthorization == .restricted {
            noPermissionView
        } else if locationProfile == nil {
            noProfileView
        } else {
            departuresList
        }
    }

    private var noPermissionView: some View {
        VStack(spacing: 10) {
            Image(systemName: "location.slash")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Location access needed")
                .font(.subheadline.weight(.semibold))
            Button("Allow Location Access") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(SBBStyle.red)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .accessibilityElement(children: .combine)
    }

    private var noProfileView: some View {
        VStack(spacing: 10) {
            Image(systemName: "location.circle")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No location watchlist set up")
                .font(.subheadline.weight(.semibold))
            Button("Create Nearby Watchlist →") {
                appState.addProfile(mode: .automatic)
                openWindow(id: "management")
            }
            .buttonStyle(.borderedProminent)
            .tint(SBBStyle.red)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var departuresList: some View {
        if quickViewRows.isEmpty {
            VStack(spacing: 6) {
                Image(systemName: "tram").foregroundStyle(.secondary)
                Text("No upcoming departures")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(20)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(quickViewRows.enumerated()), id: \.element.id) { index, snapshot in
                    QuickDepartureRow(snapshot: snapshot)
                    if index < quickViewRows.count - 1 {
                        Divider().padding(.leading, 54)
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Button("Open") { openWindow(id: "management") }
                .buttonStyle(.bordered)
                .accessibilityLabel("Open management window")
            Spacer()
            Button {
                openWindow(id: "management")
            } label: {
                Label("Manage", systemImage: "gearshape")
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Manage watchlists")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

struct QuickDepartureRow: View {
    var snapshot: DepartureSnapshot

    var body: some View {
        HStack(spacing: 12) {
            Text("\(DepartureLogic.minutesUntil(snapshot.effectiveDeparture))′")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(SBBStyle.red)
                .frame(width: 46, alignment: .trailing)

            LineBadge(
                text: snapshot.lineDisplay,
                color: SBBStyle.badgeColor(for: snapshot.lineDisplay)
            )

            VStack(alignment: .leading, spacing: 2) {
                Text("→ \(snapshot.destination)")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(snapshot.stopName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if let delay = snapshot.delayMinutes, delay > 0 {
                        Text("+\(delay)′")
                            .font(.caption)
                            .foregroundStyle(SBBStyle.redDark)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(DepartureDateFormatting.timeFormatter.string(from: snapshot.effectiveDeparture))
                    .font(.subheadline.monospacedDigit())
                if let platform = snapshot.platform, !platform.isEmpty {
                    Text(platform)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        var parts = [
            "\(snapshot.lineDisplay) to \(snapshot.destination)",
            "in \(DepartureLogic.minutesUntil(snapshot.effectiveDeparture)) minutes",
            "from \(snapshot.stopName)"
        ]
        if let delay = snapshot.delayMinutes, delay > 0 { parts.append("\(delay) minutes delayed") }
        return parts.joined(separator: ", ")
    }
}
