import SwiftUI

struct ManagementWindowView: View {
    @EnvironmentObject private var appState: DeparturesAppState
    @State private var deletingProfile: LocationProfile?

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .frame(minWidth: 780, minHeight: 540)
        .confirmationDialog(
            "Delete \"\(deletingProfile?.name ?? "")\"?",
            isPresented: Binding(
                get: { deletingProfile != nil },
                set: { if !$0 { deletingProfile = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let p = deletingProfile { appState.deleteProfile(p) }
                deletingProfile = nil
            }
            Button("Cancel", role: .cancel) { deletingProfile = nil }
        } message: {
            if let p = deletingProfile {
                let count = appState.state.favorites.filter { $0.profileId == p.id }.count
                Text("This removes \(count) saved line\(count == 1 ? "" : "s") and all departure data.")
            }
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: activeProfileSelection) {
            Section("Watchlists") {
                ForEach(appState.state.profiles) { profile in
                    SidebarProfileRow(profile: profile)
                        .tag(profile.id)
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                deletingProfile = profile
                            }
                            .disabled(appState.state.profiles.count <= 1)
                        }
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            Button {
                appState.addProfile()
            } label: {
                Label("New Watchlist", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(12)
            .accessibilityLabel("New watchlist")
        }
        .navigationTitle("Watchlists")
        .frame(minWidth: 180)
    }

    private var activeProfileSelection: Binding<UUID?> {
        Binding(
            get: { appState.state.activeProfileId },
            set: { id in
                guard let id, let profile = appState.state.profiles.first(where: { $0.id == id }) else { return }
                appState.setActiveProfile(profile)
            }
        )
    }

    // MARK: - Detail

    private var detail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ProfileDetailHeader(onDeleteProfile: {
                    deletingProfile = appState.activeProfile
                })
                DepartureBoardSection()
                WatchedLinesSection()
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(SBBStyle.milk)
        .navigationTitle(appState.activeProfile?.name ?? "Watchlist")
    }
}

// MARK: - SidebarProfileRow

struct SidebarProfileRow: View {
    @EnvironmentObject private var appState: DeparturesAppState
    var profile: LocationProfile

    var body: some View {
        HStack(spacing: 10) {
            Text(profile.displayEmoji)
                .font(.title3)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name).lineLimit(1)
                Text(profile.mode == .automatic
                     ? "Current location"
                     : "\(appState.state.favorites.filter { $0.profileId == profile.id }.count) saved")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - ProfileDetailHeader

struct ProfileDetailHeader: View {
    @EnvironmentObject private var appState: DeparturesAppState
    @State private var showingEditor = false
    var onDeleteProfile: () -> Void

    var body: some View {
        HStack {
            Text("\(appState.activeProfile?.displayEmoji ?? "🚆") \(appState.activeProfile?.name ?? "Watchlist")")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(SBBStyle.graphite)
            Spacer()
            Button {
                showingEditor = true
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit watchlist")
            .popover(isPresented: $showingEditor, arrowEdge: .top) {
                if let binding = profileBinding {
                    ProfileEditorPopover(
                        profile: binding,
                        canDelete: appState.state.profiles.count > 1,
                        onDelete: {
                            showingEditor = false
                            onDeleteProfile()
                        }
                    )
                }
            }
        }
    }

    private var profileBinding: Binding<LocationProfile>? {
        guard let profile = appState.activeProfile else { return nil }
        return Binding(
            get: { appState.state.profiles.first(where: { $0.id == profile.id }) ?? profile },
            set: { appState.updateProfile($0) }
        )
    }
}

// MARK: - ProfileEditorPopover

struct ProfileEditorPopover: View {
    @Binding var profile: LocationProfile
    var canDelete: Bool
    var onDelete: () -> Void

    private let emojiChoices = ["🏠", "💼", "📍", "🚆", "⭐️", "🎒", "☕️", "🏫"]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("Watchlist name", text: $profile.name)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 8) {
                ForEach(emojiChoices, id: \.self) { emoji in
                    Button {
                        profile.emoji = emoji
                    } label: {
                        Text(emoji)
                            .font(.title3)
                            .frame(width: 34, height: 30)
                            .background(
                                profile.displayEmoji == emoji ? SBBStyle.cloud : Color.clear,
                                in: RoundedRectangle(cornerRadius: 6)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Use \(emoji) icon")
                }
            }

            Picker("Mode", selection: $profile.mode) {
                Text("Manual").tag(LocationProfile.Mode.manual)
                Text("Auto (location)").tag(LocationProfile.Mode.automatic)
            }
            .pickerStyle(.segmented)

            Divider()

            Button("Delete Watchlist", role: .destructive, action: onDelete)
                .disabled(!canDelete)
                .accessibilityLabel("Delete this watchlist")
        }
        .padding(16)
        .frame(width: 280)
    }
}

// MARK: - DepartureBoardSection

struct DepartureBoardSection: View {
    @EnvironmentObject private var appState: DeparturesAppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("NEXT DEPARTURES")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Spacer()
                if appState.isRefreshing || appState.isRefreshingNearby {
                    ProgressView().controlSize(.small)
                } else {
                    Button {
                        Task {
                            if appState.activeProfile?.mode == .automatic {
                                await appState.refreshNearbyDepartures()
                            } else {
                                await appState.refreshNow()
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Refresh departures")
                }
            }

            if let error = appState.state.lastErrorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(SBBStyle.redDark)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white, in: RoundedRectangle(cornerRadius: 8))
            }

            if appState.dashboardSnapshots.isEmpty {
                Text("No departures — add a watched line below.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(.white, in: RoundedRectangle(cornerRadius: 8))
                    .overlay { RoundedRectangle(cornerRadius: 8).stroke(SBBStyle.cloud) }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(appState.dashboardSnapshots.prefix(12).enumerated()), id: \.element.id) { index, snapshot in
                        DepartureBoardRow(snapshot: snapshot)
                        if index < min(appState.dashboardSnapshots.count, 12) - 1 {
                            Divider()
                        }
                    }
                }
                .background(.white, in: RoundedRectangle(cornerRadius: 8))
                .overlay { RoundedRectangle(cornerRadius: 8).stroke(SBBStyle.cloud) }
            }
        }
    }
}

struct DepartureBoardRow: View {
    var snapshot: DepartureSnapshot

    var body: some View {
        HStack(spacing: 12) {
            Text("\(DepartureLogic.minutesUntil(snapshot.effectiveDeparture))′")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(SBBStyle.red)
                .frame(width: 50, alignment: .trailing)

            LineBadge(
                text: snapshot.lineDisplay,
                color: SBBStyle.badgeColor(for: snapshot.lineDisplay)
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.destination)
                    .font(.headline)
                    .foregroundStyle(SBBStyle.graphite)
                if let delay = snapshot.delayMinutes, delay > 0 {
                    Text("+\(delay) min")
                        .font(.caption)
                        .foregroundStyle(SBBStyle.redDark)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(DepartureDateFormatting.timeFormatter.string(from: snapshot.effectiveDeparture))
                    .font(.headline.monospacedDigit())
                if let platform = snapshot.platform, !platform.isEmpty {
                    Text("Pl. \(platform)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(snapshot.lineDisplay) to \(snapshot.destination) in \(DepartureLogic.minutesUntil(snapshot.effectiveDeparture)) minutes")
    }
}

// MARK: - WatchedLinesSection stub (replaced in Task 5)
struct WatchedLinesSection: View {
    var body: some View { EmptyView() }
}
