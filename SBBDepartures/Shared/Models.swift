import Foundation

let appGroupIdentifier = "group.com.local.SBBDepartures"

struct Coordinate: Codable, Hashable {
    var latitude: Double
    var longitude: Double
}

struct LocationProfile: Identifiable, Codable, Hashable {
    enum Mode: String, Codable, CaseIterable {
        case manual
        case automatic
    }

    var id: UUID
    var name: String
    var coordinate: Coordinate?
    var radiusMeters: Double?
    var mode: Mode
    var emoji: String?
    var colorHex: String?

    var displayEmoji: String {
        emoji?.isEmpty == false ? emoji! : "🚆"
    }

    var displayColorHex: String {
        colorHex?.isEmpty == false ? colorHex! : SBBPalette.redHex
    }

    static let home = LocationProfile(id: UUID(), name: "Home", coordinate: nil, radiusMeters: nil, mode: .manual, emoji: "🏠", colorHex: nil)
    static let office = LocationProfile(id: UUID(), name: "Office", coordinate: nil, radiusMeters: nil, mode: .manual, emoji: "💼", colorHex: nil)
    static let nearby = LocationProfile(id: UUID(), name: "Nearby", coordinate: nil, radiusMeters: 600, mode: .automatic, emoji: "📍", colorHex: nil)
}

struct FavoriteTransport: Identifiable, Codable, Hashable {
    var id: UUID
    var profileId: UUID
    var stopId: String
    var stopName: String
    var lineCategory: String
    var lineNumber: String
    var directionName: String
    var enabled: Bool
    var walkMinutes: Int?
    var alerts: AlertConfiguration

    var displayLine: String {
        let category = lineCategory.trimmingCharacters(in: .whitespacesAndNewlines)
        let number = lineNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        return [category, number].filter { !$0.isEmpty }.joined(separator: " ")
    }
}

struct AlertConfiguration: Codable, Hashable {
    var enabled: Bool
    var leadMinutes: Int
    var quietStartHour: Int
    var quietEndHour: Int
    var repeatSuppressionMinutes: Int

    static let quietDefault = AlertConfiguration(
        enabled: false,
        leadMinutes: 7,
        quietStartHour: 22,
        quietEndHour: 7,
        repeatSuppressionMinutes: 20
    )
}

struct DepartureSnapshot: Identifiable, Codable, Hashable {
    var id: UUID
    var favoriteId: UUID
    var profileId: UUID
    var stopName: String
    var lineDisplay: String
    var destination: String
    var plannedDeparture: Date
    var realtimeDeparture: Date?
    var delayMinutes: Int?
    var platform: String?
    var fetchedAt: Date

    var effectiveDeparture: Date {
        realtimeDeparture ?? plannedDeparture
    }
}

struct DeparturesStoreState: Codable, Hashable {
    var profiles: [LocationProfile]
    var activeProfileId: UUID
    var favorites: [FavoriteTransport]
    var snapshots: [DepartureSnapshot]
    var lastRefresh: Date?
    var lastErrorMessage: String?

    static func empty() -> DeparturesStoreState {
        let profiles: [LocationProfile] = [.home, .office, .nearby]
        return DeparturesStoreState(
            profiles: profiles,
            activeProfileId: profiles[0].id,
            favorites: [],
            snapshots: [],
            lastRefresh: nil,
            lastErrorMessage: nil
        )
    }
}

struct TransitStop: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var coordinate: Coordinate?
    var distance: Double?
}

struct StationboardDeparture: Identifiable, Codable, Hashable {
    var id: String
    var category: String
    var number: String
    var destination: String
    var plannedDeparture: Date
    var realtimeDeparture: Date?
    var platform: String?
    var delayMinutes: Int?

    var lineDisplay: String {
        [category, number].filter { !$0.isEmpty }.joined(separator: " ")
    }
}

enum DepartureLogic {
    static func matches(_ departure: StationboardDeparture, favorite: FavoriteTransport) -> Bool {
        normalize(departure.category) == normalize(favorite.lineCategory)
            && normalize(departure.number) == normalize(favorite.lineNumber)
            && normalize(departure.destination) == normalize(favorite.directionName)
    }

    static func snapshots(
        for favorite: FavoriteTransport,
        departures: [StationboardDeparture],
        fetchedAt: Date
    ) -> [DepartureSnapshot] {
        departures
            .filter { matches($0, favorite: favorite) }
            .map {
                DepartureSnapshot(
                    id: UUID(),
                    favoriteId: favorite.id,
                    profileId: favorite.profileId,
                    stopName: favorite.stopName,
                    lineDisplay: favorite.displayLine,
                    destination: $0.destination,
                    plannedDeparture: $0.plannedDeparture,
                    realtimeDeparture: $0.realtimeDeparture,
                    delayMinutes: $0.delayMinutes,
                    platform: $0.platform,
                    fetchedAt: fetchedAt
                )
            }
            .sorted { $0.effectiveDeparture < $1.effectiveDeparture }
    }

    static func minutesUntil(_ date: Date, now: Date = Date()) -> Int {
        max(0, Int(ceil(date.timeIntervalSince(now) / 60)))
    }

    static func isStale(lastRefresh: Date?, now: Date = Date(), threshold: TimeInterval = 300) -> Bool {
        guard let lastRefresh else { return true }
        return now.timeIntervalSince(lastRefresh) > threshold
    }

    private static func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}

enum SBBPalette {
    static let redHex = "#EB0000"
    static let redDarkHex = "#C60018"
    static let milkHex = "#F6F6F6"
    static let cloudHex = "#E5E5E5"
    static let metalHex = "#DCDCDC"
    static let graphiteHex = "#2D2D2D"
    static let blueHex = "#1F6AA5"
    static let greenHex = "#2E7D32"
    static let violetHex = "#7B3FA1"
    static let orangeHex = "#D86B00"
}
