import SwiftUI

// MARK: - WatchedLinesSection

struct WatchedLinesSection: View {
    @EnvironmentObject private var appState: DeparturesAppState
    @State private var expandedId: UUID?
    @State private var showingAddPanel = false
    @State private var deletingFavorite: FavoriteTransport?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader
            favoritesList
            if showingAddPanel {
                AddLinePanel(onClose: { showingAddPanel = false })
            }
        }
        .confirmationDialog(
            "Remove \(deletingFavorite.map { "\($0.displayLine) → \($0.directionName)" } ?? "")?",
            isPresented: Binding(
                get: { deletingFavorite != nil },
                set: { if !$0 { deletingFavorite = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                if let f = deletingFavorite { appState.removeFavorite(f) }
                deletingFavorite = nil
            }
            Button("Cancel", role: .cancel) { deletingFavorite = nil }
        } message: {
            Text("This will stop showing this departure.")
        }
    }

    private var sectionHeader: some View {
        HStack {
            Text("WATCHED LINES")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            Text("\(appState.activeFavorites.count)")
                .font(.caption.weight(.bold))
                .foregroundStyle(SBBStyle.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(SBBStyle.red, in: Capsule())
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showingAddPanel.toggle()
                }
            } label: {
                Label(showingAddPanel ? "Close" : "+ Add", systemImage: showingAddPanel ? "xmark" : "plus")
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(showingAddPanel ? "Close add panel" : "Add a line")
        }
    }

    @ViewBuilder
    private var favoritesList: some View {
        if appState.activeFavorites.isEmpty {
            Text("No lines saved. Tap \"+ Add\" to search for a stop and pick a line.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 70)
                .multilineTextAlignment(.center)
                .padding()
                .background(SBBStyle.white, in: RoundedRectangle(cornerRadius: 8))
                .overlay { RoundedRectangle(cornerRadius: 8).stroke(SBBStyle.cloud) }
        } else {
            VStack(spacing: 6) {
                ForEach(appState.activeFavorites) { favorite in
                    WatchedLineRow(
                        favorite: favorite,
                        isExpanded: expandedId == favorite.id,
                        onToggleExpand: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                expandedId = expandedId == favorite.id ? nil : favorite.id
                            }
                        },
                        onDelete: { deletingFavorite = favorite }
                    )
                }
            }
        }
    }
}

// MARK: - WatchedLineRow

struct WatchedLineRow: View {
    @EnvironmentObject private var appState: DeparturesAppState
    @State var favorite: FavoriteTransport
    var isExpanded: Bool
    var onToggleExpand: () -> Void
    var onDelete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            mainRow
            if isExpanded {
                Divider()
                expandedRow
            }
        }
        .background(SBBStyle.white, in: RoundedRectangle(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).stroke(SBBStyle.cloud) }
    }

    private var mainRow: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(
                get: { favorite.enabled },
                set: { v in favorite.enabled = v; appState.updateFavorite(favorite) }
            ))
            .labelsHidden()
            .tint(SBBStyle.red)
            .accessibilityLabel(favorite.enabled ? "Disable \(favorite.displayLine)" : "Enable \(favorite.displayLine)")

            LineBadge(
                text: favorite.displayLine,
                color: SBBStyle.badgeColor(for: favorite.lineCategory)
            )

            VStack(alignment: .leading, spacing: 2) {
                Text("→ \(favorite.directionName)")
                    .font(.headline)
                    .lineLimit(1)
                Text(favorite.stopName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onToggleExpand) {
                Image(systemName: isExpanded ? "chevron.up" : "ellipsis")
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isExpanded ? "Collapse options" : "Show options")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var expandedRow: some View {
        HStack(spacing: 20) {
            walkField
            alertField
            Spacer()
            Button("Remove", role: .destructive, action: onDelete)
                .font(.caption)
                .accessibilityLabel("Remove \(favorite.displayLine) → \(favorite.directionName)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(SBBStyle.milk)
    }

    private var walkField: some View {
        HStack(spacing: 6) {
            Text("Walk")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("0", value: Binding(
                get: { favorite.walkMinutes ?? 0 },
                set: { v in
                    favorite.walkMinutes = v == 0 ? nil : v
                    appState.updateFavorite(favorite)
                }
            ), format: .number)
            .textFieldStyle(.roundedBorder)
            .frame(width: 48)
            Text("min")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var alertField: some View {
        HStack(spacing: 6) {
            Toggle("Alert", isOn: Binding(
                get: { favorite.alerts.enabled },
                set: { v in favorite.alerts.enabled = v; appState.updateFavorite(favorite) }
            ))
            .font(.caption)
            .tint(SBBStyle.red)
            if favorite.alerts.enabled {
                TextField("7", value: Binding(
                    get: { favorite.alerts.leadMinutes },
                    set: { v in favorite.alerts.leadMinutes = v; appState.updateFavorite(favorite) }
                ), format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 48)
                Text("min before")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - AddLinePanel

private enum AddLineSource: String, CaseIterable, Identifiable {
    case search, nearby
    var id: String { rawValue }
    var label: String { self == .search ? "Search stop" : "Near me" }
    var icon: String { self == .search ? "magnifyingglass" : "location" }
}

struct AddLinePanel: View {
    @EnvironmentObject private var appState: DeparturesAppState
    @State private var source: AddLineSource = .search
    @State private var selectedStop: TransitStop?
    @State private var recentlyAdded: Set<String> = []
    var onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            panelHeader
            sourcePicker
            if source == .search { searchField }
            columns
        }
        .padding(14)
        .background(SBBStyle.white, in: RoundedRectangle(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).stroke(SBBStyle.cloud) }
        .onDisappear {
            appState.searchQuery = ""
        }
    }

    private var panelHeader: some View {
        HStack {
            Text("ADD A LINE")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close add panel")
        }
    }

    private var sourcePicker: some View {
        Picker("Source", selection: $source) {
            ForEach(AddLineSource.allCases) { s in
                Label(s.label, systemImage: s.icon).tag(s)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: source) { _, newValue in
            selectedStop = nil
            appState.searchQuery = ""
            if newValue == .nearby {
                Task { await appState.requestLocationAndLoadNearby() }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            TextField("Stop name, e.g. Zürich HB", text: $appState.searchQuery)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    selectedStop = nil
                    Task { await appState.searchStops() }
                }
            Button("Search") {
                selectedStop = nil
                Task { await appState.searchStops() }
            }
            .buttonStyle(.borderedProminent)
            .tint(SBBStyle.red)
        }
    }

    private var columns: some View {
        HStack(alignment: .top, spacing: 14) {
            stopColumn
            lineColumn
        }
        .frame(minHeight: 180)
    }

    private var stopColumn: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("① STOP")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            if appState.searchResults.isEmpty {
                columnHint(source == .search
                    ? "Search a stop name to begin."
                    : "Loading nearby stops…")
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(appState.searchResults) { stop in
                            StopPickerRow(stop: stop, isSelected: selectedStop?.id == stop.id)
                                .onTapGesture {
                                    selectedStop = stop
                                    Task { await appState.loadCandidates(for: stop) }
                                }
                                .accessibilityAddTraits(selectedStop?.id == stop.id ? .isSelected : [])
                        }
                    }
                    .padding(4)
                }
                .frame(maxHeight: 200)
                .background(SBBStyle.milk, in: RoundedRectangle(cornerRadius: 6))
            }
        }
        .frame(minWidth: 180, maxWidth: 260)
    }

    private var lineColumn: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(selectedStop == nil
                 ? "② LINE / DIRECTION"
                 : "② FROM \(selectedStop!.name.uppercased())")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if selectedStop == nil {
                columnHint("Select a stop to see lines.")
            } else if appState.candidateDepartures.isEmpty {
                columnHint("Loading lines…")
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(appState.candidateDepartures) { departure in
                            let key = "\(departure.category)-\(departure.number)-\(departure.destination)"
                            let saved = selectedStop.map {
                                appState.hasFavorite(
                                    stopId: $0.id,
                                    category: departure.category,
                                    number: departure.number,
                                    destination: departure.destination
                                )
                            } ?? false

                            CandidateLineRow(
                                departure: departure,
                                alreadySaved: saved,
                                justAdded: recentlyAdded.contains(key)
                            ) {
                                guard let stop = selectedStop else { return }
                                appState.addFavorite(stop: stop, departure: departure)
                                recentlyAdded.insert(key)
                                Task {
                                    try? await Task.sleep(for: .seconds(1.5))
                                    recentlyAdded.remove(key)
                                }
                            }
                        }
                    }
                    .padding(4)
                }
                .frame(maxHeight: 200)
                .background(SBBStyle.milk, in: RoundedRectangle(cornerRadius: 6))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func columnHint(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 80)
            .multilineTextAlignment(.center)
            .padding(8)
            .background(SBBStyle.milk, in: RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - StopPickerRow

struct StopPickerRow: View {
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
        .background(isSelected ? SBBStyle.white : Color.clear, in: RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? SBBStyle.red : Color.clear)
        }
    }
}

// MARK: - CandidateLineRow

struct CandidateLineRow: View {
    var departure: StationboardDeparture
    var alreadySaved: Bool
    var justAdded: Bool
    var onAdd: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            LineBadge(
                text: departure.lineDisplay,
                color: SBBStyle.badgeColor(for: departure.category)
            )
            VStack(alignment: .leading, spacing: 2) {
                Text("→ \(departure.destination)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(alreadySaved ? .secondary : SBBStyle.graphite)
                    .lineLimit(1)
                Text(DepartureDateFormatting.timeFormatter.string(
                    from: departure.realtimeDeparture ?? departure.plannedDeparture))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if alreadySaved {
                Text("already saved")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if justAdded {
                Label("Added", systemImage: "checkmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SBBStyle.green)
            } else {
                Button("+ Add", action: onAdd)
                    .buttonStyle(.borderedProminent)
                    .tint(SBBStyle.red)
                    .controlSize(.small)
                    .accessibilityLabel("Add \(departure.lineDisplay) to \(departure.destination)")
            }
        }
        .padding(10)
        .background(SBBStyle.white, in: RoundedRectangle(cornerRadius: 6))
        .opacity(alreadySaved ? 0.6 : 1.0)
    }
}
