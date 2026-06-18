import SwiftUI

struct ManagementWindowView: View {
    @EnvironmentObject private var appState: DeparturesAppState
    @State private var deletingProfile: LocationProfile?
    @State private var showingNewWatchlist = false

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
        .sheet(isPresented: $showingNewWatchlist) {
            NewWatchlistSheet()
                .environmentObject(appState)
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
                showingNewWatchlist = true
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
        .background(Color(NSColor.windowBackgroundColor))
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
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit watchlist")
            .sheet(isPresented: $showingEditor) {
                if let binding = profileBinding {
                    ProfileEditorSheet(
                        profile: binding,
                        canDelete: appState.state.profiles.count > 1,
                        onDelete: {
                            showingEditor = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                onDeleteProfile()
                            }
                        }
                    )
                    .environmentObject(appState)
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

// MARK: - ProfileEditorSheet (new, replaces ProfileEditorPopover)

struct ProfileEditorSheet: View {
    @Binding var profile: LocationProfile
    var canDelete: Bool
    var onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var nameFocused: Bool

    private let emojiChoices = ["🏠", "💼", "📍", "🚆", "⭐️", "🎒", "☕️", "🏫"]

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Spacer()
                Text("Edit Watchlist")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .tint(SBBStyle.red)
                    .keyboardShortcut(.return, modifiers: [])
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    editorSection(title: "NAME") {
                        TextField("Watchlist name", text: $profile.name)
                            .textFieldStyle(.roundedBorder)
                            .focused($nameFocused)
                    }

                    editorSection(title: "ICON") {
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8),
                            spacing: 8
                        ) {
                            ForEach(emojiChoices, id: \.self) { emoji in
                                emojiCell(emoji, selected: profile.displayEmoji == emoji) {
                                    profile.emoji = emoji
                                }
                            }
                        }
                    }

                    editorSection(title: "TYPE") {
                        Picker("Mode", selection: $profile.mode) {
                            Label("Manual — add stops yourself", systemImage: "hand.tap")
                                .tag(LocationProfile.Mode.manual)
                            Label("Auto — use current location", systemImage: "location")
                                .tag(LocationProfile.Mode.automatic)
                        }
                        .pickerStyle(.radioGroup)
                    }

                    if canDelete {
                        Divider()
                        Button(role: .destructive, action: onDelete) {
                            Label("Delete Watchlist", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .foregroundStyle(SBBStyle.redDark)
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 360)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear { nameFocused = true }
    }

    private func editorSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func emojiCell(_ emoji: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(emoji)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(
                    selected ? SBBStyle.red.opacity(0.12) : Color(NSColor.controlBackgroundColor),
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            selected ? SBBStyle.red : Color(NSColor.separatorColor),
                            lineWidth: selected ? 2 : 0.5
                        )
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Set icon to \(emoji)")
    }
}

// MARK: - NewWatchlistSheet (new)

struct NewWatchlistSheet: View {
    @EnvironmentObject private var appState: DeparturesAppState
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var emoji = "⭐️"
    @State private var mode: LocationProfile.Mode = .manual
    @FocusState private var nameFocused: Bool

    private let emojiChoices = ["🏠", "💼", "📍", "🚆", "⭐️", "🎒", "☕️", "🏫"]

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape, modifiers: [])
                Spacer()
                Text("New Watchlist")
                    .font(.headline)
                Spacer()
                Button("Create") { create() }
                    .buttonStyle(.borderedProminent)
                    .tint(SBBStyle.red)
                    .disabled(trimmedName.isEmpty)
                    .keyboardShortcut(.return, modifiers: [])
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    creatorSection(title: "NAME") {
                        TextField("e.g. Home, Office, Station…", text: $name)
                            .textFieldStyle(.roundedBorder)
                            .focused($nameFocused)
                    }

                    creatorSection(title: "ICON") {
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8),
                            spacing: 8
                        ) {
                            ForEach(emojiChoices, id: \.self) { e in
                                emojiCell(e, selected: emoji == e) { emoji = e }
                            }
                        }
                    }

                    creatorSection(title: "TYPE") {
                        Picker("Mode", selection: $mode) {
                            Label("Manual — add stops yourself", systemImage: "hand.tap")
                                .tag(LocationProfile.Mode.manual)
                            Label("Auto — use current location", systemImage: "location")
                                .tag(LocationProfile.Mode.automatic)
                        }
                        .pickerStyle(.radioGroup)
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 360, height: 420)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear { nameFocused = true }
    }

    private func create() {
        guard !trimmedName.isEmpty else { return }
        let profile = LocationProfile(
            id: UUID(),
            name: trimmedName,
            coordinate: nil,
            radiusMeters: mode == .automatic ? 600 : nil,
            mode: mode,
            emoji: emoji,
            colorHex: nil
        )
        appState.insertProfile(profile)
        dismiss()
    }

    private func creatorSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func emojiCell(_ e: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(e)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(
                    selected ? SBBStyle.red.opacity(0.12) : Color(NSColor.controlBackgroundColor),
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            selected ? SBBStyle.red : Color(NSColor.separatorColor),
                            lineWidth: selected ? 2 : 0.5
                        )
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Set icon to \(e)")
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
                    .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                    .overlay { RoundedRectangle(cornerRadius: 8).stroke(Color(NSColor.separatorColor)) }
            }

            let rows = Array(appState.dashboardSnapshots.prefix(12))
            if rows.isEmpty {
                Text("No departures — add a watched line below.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                    .overlay { RoundedRectangle(cornerRadius: 8).stroke(Color(NSColor.separatorColor)) }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, snapshot in
                        DepartureBoardRow(snapshot: snapshot)
                        if index < rows.count - 1 {
                            Divider()
                        }
                    }
                }
                .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                .overlay { RoundedRectangle(cornerRadius: 8).stroke(Color(NSColor.separatorColor)) }
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
        .accessibilityLabel({
            let delay = snapshot.delayMinutes ?? 0
            let delaySuffix = delay > 0 ? ", \(delay) minute delay" : ""
            return "\(snapshot.lineDisplay) to \(snapshot.destination) in \(DepartureLogic.minutesUntil(snapshot.effectiveDeparture)) minutes\(delaySuffix)"
        }())
    }
}
