import CoreLocation
import Foundation
import SwiftUI
import WidgetKit

@MainActor
final class DeparturesAppState: NSObject, ObservableObject {
    @Published private(set) var state: DeparturesStoreState
    @Published var searchQuery = ""
    @Published private(set) var searchResults: [TransitStop] = []
    @Published private(set) var candidateDepartures: [StationboardDeparture] = []
    @Published private(set) var nearbySnapshots: [DepartureSnapshot] = []
    @Published private(set) var nearbyStops: [TransitStop] = []
    @Published private(set) var isRefreshingNearby = false
    @Published private(set) var isRefreshing = false
    @Published private(set) var locationAuthorization: CLAuthorizationStatus = .notDetermined

    private let api = TransportAPI()
    private let store: SharedStore
    private let notifications = NotificationService()
    private let locationManager = CLLocationManager()
    private var refreshTask: Task<Void, Never>?

    init(store: SharedStore = .shared) {
        self.store = store
        self.state = store.load()
        super.init()
        locationManager.delegate = self
        locationAuthorization = locationManager.authorizationStatus
        refreshTask = Task { [weak self] in
            await self?.runRefreshLoop()
        }
    }

    deinit {
        refreshTask?.cancel()
    }

    var activeProfile: LocationProfile? {
        state.profiles.first { $0.id == state.activeProfileId }
    }

    var activeSnapshots: [DepartureSnapshot] {
        state.snapshots
            .filter { $0.profileId == state.activeProfileId && $0.effectiveDeparture >= Date().addingTimeInterval(-60) }
            .sorted { $0.effectiveDeparture < $1.effectiveDeparture }
    }

    var allUpcomingSnapshots: [DepartureSnapshot] {
        state.snapshots
            .filter { $0.effectiveDeparture >= Date().addingTimeInterval(-60) }
            .sorted { $0.effectiveDeparture < $1.effectiveDeparture }
    }

    var activeFavorites: [FavoriteTransport] {
        state.favorites
            .filter { $0.profileId == state.activeProfileId }
            .sorted { $0.stopName < $1.stopName }
    }

    var dashboardSnapshots: [DepartureSnapshot] {
        if activeProfile?.mode == .automatic, !nearbySnapshots.isEmpty {
            return nearbySnapshots
                .filter { $0.effectiveDeparture >= Date().addingTimeInterval(-60) }
                .sorted { $0.effectiveDeparture < $1.effectiveDeparture }
        }
        return activeSnapshots
    }

    var menuBarTitle: String {
        guard let next = activeSnapshots.first else { return "SBB" }
        let minutes = DepartureLogic.minutesUntil(next.effectiveDeparture)
        return "\(next.lineDisplay) \(minutes)m"
    }

    var staleText: String? {
        guard DepartureLogic.isStale(lastRefresh: state.lastRefresh) else { return nil }
        return state.lastRefresh == nil ? "No refresh yet" : "Data may be stale"
    }

    func setActiveProfile(_ profile: LocationProfile) {
        state.activeProfileId = profile.id
        persist()
        Task {
            if profile.mode == .automatic {
                await refreshNearbyDepartures()
            } else {
                await refreshNow()
            }
        }
    }

    func addProfile() {
        let profile = LocationProfile(
            id: UUID(),
            name: "New profile",
            coordinate: nil,
            radiusMeters: nil,
            mode: .manual,
            emoji: "⭐️",
            colorHex: nil
        )
        state.profiles.append(profile)
        state.activeProfileId = profile.id
        persist()
    }

    func updateProfile(_ profile: LocationProfile) {
        guard let index = state.profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        state.profiles[index] = profile
        persist()
    }

    func deleteProfile(_ profile: LocationProfile) {
        guard state.profiles.count > 1 else { return }
        state.profiles.removeAll { $0.id == profile.id }
        let favoriteIds = Set(state.favorites.filter { $0.profileId == profile.id }.map(\.id))
        state.favorites.removeAll { $0.profileId == profile.id }
        state.snapshots.removeAll { $0.profileId == profile.id || favoriteIds.contains($0.favoriteId) }
        if state.activeProfileId == profile.id {
            state.activeProfileId = state.profiles[0].id
        }
        persist()
    }

    func searchStops() async {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else {
            searchResults = []
            candidateDepartures = []
            return
        }

        do {
            searchResults = try await api.searchStops(query: query)
            candidateDepartures = []
            state.lastErrorMessage = nil
        } catch {
            state.lastErrorMessage = error.localizedDescription
        }
        persist()
    }

    func loadCandidates(for stop: TransitStop) async {
        do {
            candidateDepartures = uniqueLineDirections(try await api.stationboard(stopIdOrName: stop.id))
            state.lastErrorMessage = nil
        } catch {
            candidateDepartures = []
            state.lastErrorMessage = error.localizedDescription
        }
        persist()
    }

    func addFavorite(stop: TransitStop, departure: StationboardDeparture) {
        let favorite = FavoriteTransport(
            id: UUID(),
            profileId: state.activeProfileId,
            stopId: stop.id,
            stopName: stop.name,
            lineCategory: departure.category,
            lineNumber: departure.number,
            directionName: departure.destination,
            enabled: true,
            walkMinutes: nil,
            alerts: .quietDefault
        )
        state.favorites.append(favorite)
        persist()
        Task { await refreshNow() }
    }

    func removeFavorites(at offsets: IndexSet) {
        let ids = offsets.map { activeFavorites[$0].id }
        removeFavorites(ids: ids)
    }

    func removeFavorite(_ favorite: FavoriteTransport) {
        removeFavorites(ids: [favorite.id])
    }

    private func removeFavorites(ids: [UUID]) {
        state.favorites.removeAll { ids.contains($0.id) }
        state.snapshots.removeAll { ids.contains($0.favoriteId) }
        persist()
    }

    func updateFavorite(_ favorite: FavoriteTransport) {
        guard let index = state.favorites.firstIndex(where: { $0.id == favorite.id }) else { return }
        state.favorites[index] = favorite
        persist()
    }

    func requestLocationAndLoadNearby() async {
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
        locationManager.startUpdatingLocation()

        guard let location = locationManager.location else {
            state.lastErrorMessage = "Waiting for the current location."
            persist()
            return
        }

        do {
            searchResults = try await api.nearbyStops(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
            candidateDepartures = []
            state.lastErrorMessage = nil
        } catch {
            state.lastErrorMessage = error.localizedDescription
        }
        persist()
    }

    func refreshNearbyDepartures() async {
        guard !isRefreshingNearby else { return }
        isRefreshingNearby = true
        defer { isRefreshingNearby = false }

        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
        locationManager.startUpdatingLocation()

        guard let location = locationManager.location else {
            state.lastErrorMessage = "Waiting for the current location."
            persist()
            return
        }

        do {
            let stops = try await api.nearbyStops(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
            nearbyStops = Array(stops.prefix(5))
            let now = Date()
            var snapshots: [DepartureSnapshot] = []

            for stop in nearbyStops.prefix(3) {
                let departures = try await api.stationboard(stopIdOrName: stop.id, limit: 8)
                snapshots += departures.prefix(5).map { departure in
                    DepartureSnapshot(
                        id: UUID(),
                        favoriteId: UUID(),
                        profileId: state.activeProfileId,
                        stopName: stop.name,
                        lineDisplay: departure.lineDisplay,
                        destination: departure.destination,
                        plannedDeparture: departure.plannedDeparture,
                        realtimeDeparture: departure.realtimeDeparture,
                        delayMinutes: departure.delayMinutes,
                        platform: departure.platform,
                        fetchedAt: now
                    )
                }
            }

            nearbySnapshots = Array(snapshots.sorted { $0.effectiveDeparture < $1.effectiveDeparture }.prefix(12))
            state.lastRefresh = now
            state.lastErrorMessage = nil
        } catch {
            state.lastErrorMessage = error.localizedDescription
        }

        persist()
    }

    func requestNotificationPermission() async {
        _ = await notifications.requestPermission()
    }

    func refreshNow() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let now = Date()
        var newSnapshots: [DepartureSnapshot] = []

        do {
            for favorite in state.favorites where favorite.enabled {
                let departures = try await api.stationboard(stopIdOrName: favorite.stopId)
                newSnapshots += DepartureLogic.snapshots(for: favorite, departures: departures, fetchedAt: now).prefix(6)
            }
            state.snapshots = newSnapshots.sorted { $0.effectiveDeparture < $1.effectiveDeparture }
            state.lastRefresh = now
            state.lastErrorMessage = nil
            notifications.evaluate(snapshots: state.snapshots, favorites: state.favorites, now: now)
        } catch {
            state.lastErrorMessage = error.localizedDescription
        }

        persist()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func runRefreshLoop() async {
        await refreshNow()
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(60))
            await refreshNow()
        }
    }

    private func uniqueLineDirections(_ departures: [StationboardDeparture]) -> [StationboardDeparture] {
        var seen = Set<String>()
        return departures.filter { departure in
            let key = "\(departure.category)-\(departure.number)-\(departure.destination)"
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
    }

    private func persist() {
        do {
            try store.save(state)
        } catch {
            state.lastErrorMessage = error.localizedDescription
        }
    }
}

extension DeparturesAppState: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            locationAuthorization = manager.authorizationStatus
        }
    }
}
