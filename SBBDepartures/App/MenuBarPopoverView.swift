import SwiftUI

struct MenuBarPopoverView: View {
    @EnvironmentObject private var appState: DeparturesAppState
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            profilePicker
            staleBanner
            departuresList
            Divider()
            controls
        }
        .padding(16)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("SBB Departures")
                    .font(.headline)
                Text(appState.activeProfile?.name ?? "No profile")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if appState.isRefreshing {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    private var profilePicker: some View {
        Picker("Profile", selection: Binding(
            get: { appState.state.activeProfileId },
            set: { id in
                if let profile = appState.state.profiles.first(where: { $0.id == id }) {
                    appState.setActiveProfile(profile)
                }
            }
        )) {
            ForEach(appState.state.profiles) { profile in
                Text(profile.name).tag(profile.id)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var staleBanner: some View {
        if let staleText = appState.staleText {
            Label(staleText, systemImage: "clock.badge.exclamationmark")
                .font(.caption)
                .foregroundStyle(.orange)
        }

        if let error = appState.state.lastErrorMessage {
            Label(error, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.red)
                .lineLimit(2)
        }
    }

    private var departuresList: some View {
        Group {
            if appState.activeSnapshots.isEmpty {
                ContentUnavailableView(
                    "No departures",
                    systemImage: "tram",
                    description: Text("Add a stop, line, and direction in Settings.")
                )
                .frame(height: 170)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(appState.activeSnapshots.prefix(8)) { snapshot in
                            DepartureRow(snapshot: snapshot)
                        }
                    }
                }
                .frame(maxHeight: 270)
            }
        }
    }

    private var controls: some View {
        HStack {
            Button {
                Task { await appState.refreshNow() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(appState.isRefreshing)

            Spacer()

            Button {
                openSettings()
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
        }
    }
}

struct DepartureRow: View {
    var snapshot: DepartureSnapshot

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(DepartureLogic.minutesUntil(snapshot.effectiveDeparture))")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .frame(width: 46, alignment: .trailing)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(snapshot.lineDisplay)
                        .font(.headline)
                    Text("to \(snapshot.destination)")
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }
                Text(snapshot.stopName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(DepartureDateFormatting.timeFormatter.string(from: snapshot.effectiveDeparture))
                    .font(.subheadline)
                    .monospacedDigit()
                HStack(spacing: 6) {
                    if let delay = snapshot.delayMinutes, delay > 0 {
                        Text("+\(delay)")
                            .foregroundStyle(.red)
                    }
                    if let platform = snapshot.platform, !platform.isEmpty {
                        Text(platform)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
    }
}
