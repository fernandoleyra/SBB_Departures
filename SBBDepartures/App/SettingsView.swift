import SwiftUI

struct ManageSheetView: View {
    @EnvironmentObject private var appState: DeparturesAppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Manage Watchlist")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(SBBStyle.graphite)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Text("Done")
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(.white)

            Divider()

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 16) {
                    watchlistList
                    if let profileBinding {
                        ProfileEditor(profile: profileBinding)
                    }
                }
                .padding(18)
                .frame(width: 300, alignment: .top)
                .background(.white)

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Add a saved departure")
                            .font(.headline)
                            .foregroundStyle(SBBStyle.graphite)
                        AddFavoritePanel()
                        WatchlistSection()
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(SBBStyle.milk)
            }
        }
    }

    private var watchlistList: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Watchlists")
                    .font(.headline)
                Spacer()
                Button {
                    appState.addProfile()
                } label: {
                    Label("New", systemImage: "plus")
                }
                .labelStyle(.iconOnly)
                .accessibilityLabel("New watchlist")
            }

            VStack(spacing: 4) {
                ForEach(appState.state.profiles) { profile in
                    Button {
                        appState.setActiveProfile(profile)
                    } label: {
                        WatchlistSelectorRow(
                            profile: profile,
                            isSelected: profile.id == appState.state.activeProfileId,
                            favoritesCount: appState.state.favorites.filter { $0.profileId == profile.id }.count
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var profileBinding: Binding<LocationProfile>? {
        guard let profile = appState.activeProfile else { return nil }
        return Binding(
            get: {
                appState.state.profiles.first(where: { $0.id == profile.id }) ?? profile
            },
            set: { updated in
                appState.updateProfile(updated)
            }
        )
    }
}

struct WatchlistSelectorRow: View {
    var profile: LocationProfile
    var isSelected: Bool
    var favoritesCount: Int

    var body: some View {
        HStack(spacing: 10) {
            Text(profile.displayEmoji)
                .font(.title3)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(profile.mode == .automatic ? "Current location" : "\(favoritesCount) saved")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(SBBStyle.red)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(isSelected ? SBBStyle.cloud : Color.clear, in: RoundedRectangle(cornerRadius: 7))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(profile.name), \(profile.mode == .automatic ? "current location" : "\(favoritesCount) saved departures")")
    }
}

struct SettingsView: View {
    @EnvironmentObject private var appState: DeparturesAppState
    @State private var selectedProfileId: UUID?

    var body: some View {
        NavigationSplitView {
            List(selection: profileSelection) {
                Section("Watchlists") {
                    ForEach(appState.state.profiles) { profile in
                        HStack(spacing: 10) {
                            Text(profile.displayEmoji)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(profile.name)
                                Text(profile.mode == .automatic ? "Uses current location" : "Manual stops")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tag(profile.id)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    appState.addProfile()
                    selectedProfileId = appState.state.activeProfileId
                } label: {
                    Label("New Watchlist", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(SBBStyle.red)
                .padding()
            }
            .navigationTitle("Watchlists")
            .onAppear {
                selectedProfileId = appState.state.activeProfileId
            }
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    if let profileBinding {
                        ProfileEditor(profile: profileBinding)
                    }
                    AddFavoritePanel()
                    WatchlistSection()
                }
                .padding(24)
            }
            .background(SBBStyle.milk)
            .navigationTitle(appState.activeProfile?.name ?? "Departures")
        }
    }

    private var profileSelection: Binding<UUID?> {
        Binding(
            get: { selectedProfileId ?? appState.state.activeProfileId },
            set: { id in
                selectedProfileId = id
                if let id, let profile = appState.state.profiles.first(where: { $0.id == id }) {
                    appState.setActiveProfile(profile)
                }
            }
        )
    }

    private var profileBinding: Binding<LocationProfile>? {
        let id = selectedProfileId ?? appState.state.activeProfileId
        guard let profile = appState.state.profiles.first(where: { $0.id == id }) else {
            return nil
        }

        return Binding(
            get: {
                appState.state.profiles.first(where: { $0.id == profile.id }) ?? profile
            },
            set: { updated in
                appState.updateProfile(updated)
            }
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("\(appState.activeProfile?.displayEmoji ?? "🚆") \(appState.activeProfile?.name ?? "Watchlist")")
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(SBBStyle.graphite)
            Text("Build this watchlist from a named stop or from stops near your current location.")
                .foregroundStyle(.secondary)
        }
    }
}

struct ProfileEditor: View {
    @EnvironmentObject private var appState: DeparturesAppState
    @Binding var profile: LocationProfile

    private let emojiChoices = ["🏠", "💼", "📍", "🚆", "⭐️", "🎒", "☕️", "🏫"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Profile")
                    .font(.headline)
                Spacer()
                Button(role: .destructive) {
                    appState.deleteProfile(profile)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .disabled(appState.state.profiles.count <= 1)
                .accessibilityLabel("Delete watchlist")
            }

            HStack(spacing: 12) {
                TextField("Watchlist name", text: Binding(
                    get: { profile.name },
                    set: { profile.name = $0 }
                ))
                .textFieldStyle(.roundedBorder)

                Picker("Mode", selection: Binding(
                    get: { profile.mode },
                    set: { profile.mode = $0 }
                )) {
                    Text("Manual").tag(LocationProfile.Mode.manual)
                    Text("Auto").tag(LocationProfile.Mode.automatic)
                }
                .pickerStyle(.segmented)
                .frame(width: 170)
            }

            HStack(spacing: 8) {
                ForEach(emojiChoices, id: \.self) { emoji in
                    Button {
                        profile.emoji = emoji
                    } label: {
                        Text(emoji)
                            .font(.title3)
                            .frame(width: 34, height: 30)
                            .background(profile.displayEmoji == emoji ? SBBStyle.cloud : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Use \(emoji) icon")
                }
            }
        }
        .padding(14)
        .background(.white, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(SBBStyle.cloud)
        }
    }
}

struct AddFavoritePanel: View {
    private enum StopSource: String, CaseIterable, Identifiable {
        case manual
        case location

        var id: String { rawValue }
        var title: String {
            switch self {
            case .manual: "Search stop"
            case .location: "Current location"
            }
        }
    }

    @EnvironmentObject private var appState: DeparturesAppState
    @State private var source: StopSource = .manual
    @State private var selectedStop: TransitStop?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Add bus or train")
                        .font(.headline)
                    Text("First select the stop. Then add one or more live line directions.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Picker("Source", selection: $source) {
                    ForEach(StopSource.allCases) { source in
                        Text(source.title).tag(source)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 260)
                .onChange(of: source) { _, newValue in
                    selectedStop = nil
                    if newValue == .location {
                        Task { await appState.requestLocationAndLoadNearby() }
                    }
                }
            }

            if source == .manual {
                manualSearch
            } else {
                locationSearch
            }

            HStack(alignment: .top, spacing: 14) {
                stopColumn
                departureColumn
            }
            .frame(minHeight: 240)
        }
        .padding(14)
        .background(.white, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(SBBStyle.cloud)
        }
    }

    private var manualSearch: some View {
        HStack(spacing: 8) {
            TextField("Stop name, e.g. Zürich HB", text: $appState.searchQuery)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    selectedStop = nil
                    Task { await appState.searchStops() }
                }

            Button {
                selectedStop = nil
                Task { await appState.searchStops() }
            } label: {
                Label("Search", systemImage: "magnifyingglass")
            }
            .buttonStyle(.borderedProminent)
            .tint(SBBStyle.red)
        }
    }

    private var locationSearch: some View {
        HStack(spacing: 8) {
            Label("Location finds nearby stops first; you still choose which stop and line to save.", systemImage: "location")
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                selectedStop = nil
                Task { await appState.requestLocationAndLoadNearby() }
            } label: {
                Label("Load Nearby Stops", systemImage: "location.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(SBBStyle.red)
        }
    }

    private var stopColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            columnHeader("1", "Stop")

            if appState.searchResults.isEmpty {
                emptyColumnText(source == .manual ? "Search a stop name to begin." : "Load nearby stops from your current location.")
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(appState.searchResults) { stop in
                            Button {
                                selectedStop = stop
                                Task { await appState.loadCandidates(for: stop) }
                            } label: {
                                StopResultRow(stop: stop, isSelected: selectedStop?.id == stop.id)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(stopAccessibilityLabel(stop))
                        }
                    }
                    .padding(6)
                }
                .background(SBBStyle.milk.opacity(0.7), in: RoundedRectangle(cornerRadius: 6))
            }
        }
        .frame(minWidth: 300, maxWidth: 340)
    }

    private var departureColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            columnHeader("2", selectedStop == nil ? "Line direction" : "Lines from \(selectedStop!.name)")

            if selectedStop == nil {
                emptyColumnText("Select a stop to load buses, trains, trams, and directions.")
            } else if appState.candidateDepartures.isEmpty {
                emptyColumnText("Loading departures, or no upcoming services were returned for this stop.")
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(appState.candidateDepartures) { departure in
                            Button {
                                if let selectedStop {
                                    appState.addFavorite(stop: selectedStop, departure: departure)
                                }
                            } label: {
                                CandidateDepartureRow(departure: departure)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Add \(departure.lineDisplay) to \(departure.destination), departing at \(DepartureDateFormatting.timeFormatter.string(from: departure.realtimeDeparture ?? departure.plannedDeparture))")
                        }
                    }
                    .padding(6)
                }
                .background(SBBStyle.milk.opacity(0.7), in: RoundedRectangle(cornerRadius: 6))
            }
        }
        .frame(minWidth: 390)
    }

    private func columnHeader(_ number: String, _ title: String) -> some View {
        HStack(spacing: 8) {
            Text(number)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(SBBStyle.red, in: Circle())
            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
        }
    }

    private func emptyColumnText(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 170)
            .multilineTextAlignment(.center)
            .padding()
            .background(SBBStyle.milk.opacity(0.7), in: RoundedRectangle(cornerRadius: 6))
    }

    private func stopAccessibilityLabel(_ stop: TransitStop) -> String {
        if let distance = stop.distance {
            return "Select stop \(stop.name), \(Int(distance)) meters away"
        }
        return "Select stop \(stop.name)"
    }
}

struct StopResultRow: View {
    var stop: TransitStop
    var isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "mappin.circle")
                .foregroundStyle(isSelected ? SBBStyle.red : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(stop.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SBBStyle.graphite)
                    .lineLimit(1)
                if let distance = stop.distance {
                    Text("\(Int(distance)) m away")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(10)
        .background(isSelected ? .white : Color.clear, in: RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? SBBStyle.red : Color.clear)
        }
    }
}

struct CandidateDepartureRow: View {
    var departure: StationboardDeparture

    var body: some View {
        HStack(spacing: 10) {
            LineBadge(text: departure.lineDisplay)
            VStack(alignment: .leading, spacing: 2) {
                Text("to \(departure.destination)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SBBStyle.graphite)
                    .lineLimit(1)
                Text(DepartureDateFormatting.timeFormatter.string(from: departure.realtimeDeparture ?? departure.plannedDeparture))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(SBBStyle.red)
        }
        .padding(10)
        .background(.white, in: RoundedRectangle(cornerRadius: 6))
    }
}

struct WatchlistSection: View {
    @EnvironmentObject private var appState: DeparturesAppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Saved in this watchlist")
                    .font(.headline)
                    .foregroundStyle(SBBStyle.graphite)
                Text("\(appState.activeFavorites.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(SBBStyle.red, in: Capsule())
                Spacer()
                Button {
                    Task { await appState.refreshNow() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(appState.isRefreshing)
            }

            if appState.activeFavorites.isEmpty {
                Text("Nothing saved yet. Pick a stop above and add the exact line direction you want to watch.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 100)
                    .padding()
                    .background(.white, in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(SBBStyle.cloud)
                    }
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(appState.activeFavorites) { favorite in
                        FavoriteEditorRow(favorite: favorite)
                            .padding(12)
                            .background(.white, in: RoundedRectangle(cornerRadius: 8))
                            .overlay {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(SBBStyle.cloud)
                            }
                    }
                }
            }
        }
    }
}

struct FavoriteEditorRow: View {
    @EnvironmentObject private var appState: DeparturesAppState
    @State var favorite: FavoriteTransport

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Toggle("", isOn: Binding(
                    get: { favorite.enabled },
                    set: { favorite.enabled = $0; appState.updateFavorite(favorite) }
                ))
                .labelsHidden()

                LineBadge(text: favorite.displayLine)

                VStack(alignment: .leading, spacing: 2) {
                    Text("to \(favorite.directionName)")
                        .font(.headline)
                        .lineLimit(1)
                    Text(favorite.stopName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Stepper(value: Binding(
                    get: { favorite.walkMinutes ?? 0 },
                    set: { favorite.walkMinutes = $0 == 0 ? nil : $0; appState.updateFavorite(favorite) }
                ), in: 0...30) {
                    Text("Walk \(favorite.walkMinutes ?? 0) min")
                }
                .frame(width: 150)

                Button(role: .destructive) {
                    appState.removeFavorite(favorite)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Delete \(favorite.displayLine) to \(favorite.directionName)")
            }

            HStack {
                Toggle("Alerts", isOn: Binding(
                    get: { favorite.alerts.enabled },
                    set: { favorite.alerts.enabled = $0; appState.updateFavorite(favorite) }
                ))
                Stepper(value: Binding(
                    get: { favorite.alerts.leadMinutes },
                    set: { favorite.alerts.leadMinutes = $0; appState.updateFavorite(favorite) }
                ), in: 1...30) {
                    Text("Lead \(favorite.alerts.leadMinutes) min")
                }
                Spacer()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
