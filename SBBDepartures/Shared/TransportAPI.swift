import Foundation

enum TransportAPIError: LocalizedError {
    case invalidURL
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The transport API URL could not be created."
        case .invalidResponse:
            return "The transport API returned an unexpected response."
        }
    }
}

actor TransportAPI {
    private let baseURL = URL(string: "https://transport.opendata.ch/v1")!
    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .shared) {
        self.session = session
        self.decoder = .transportAPI
    }

    func searchStops(query: String) async throws -> [TransitStop] {
        let response: LocationsResponse = try await get(
            path: "locations",
            queryItems: [
                URLQueryItem(name: "query", value: query),
                URLQueryItem(name: "type", value: "station")
            ]
        )
        return response.stations.compactMap(TransitStop.init(apiStation:))
    }

    func nearbyStops(latitude: Double, longitude: Double) async throws -> [TransitStop] {
        let response: LocationsResponse = try await get(
            path: "locations",
            queryItems: [
                URLQueryItem(name: "x", value: String(latitude)),
                URLQueryItem(name: "y", value: String(longitude))
            ]
        )
        return response.stations.compactMap(TransitStop.init(apiStation:))
    }

    func stationboard(stopIdOrName: String, limit: Int = 40) async throws -> [StationboardDeparture] {
        let response: StationboardResponse = try await get(
            path: "stationboard",
            queryItems: [
                URLQueryItem(name: "station", value: stopIdOrName),
                URLQueryItem(name: "limit", value: String(limit))
            ]
        )
        return response.stationboard.compactMap(StationboardDeparture.init(apiDeparture:))
    }

    private func get<T: Decodable>(path: String, queryItems: [URLQueryItem]) async throws -> T {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        components?.queryItems = queryItems
        guard let url = components?.url else { throw TransportAPIError.invalidURL }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw TransportAPIError.invalidResponse
        }
        return try decoder.decode(T.self, from: data)
    }
}

extension JSONDecoder {
    static var transportAPI: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = TransportAPIDateFormatter.primary.date(from: value) {
                return date
            }
            if let date = ISO8601DateFormatter().date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid transport API date: \(value)"
            )
        }
        return decoder
    }
}

private enum TransportAPIDateFormatter {
    static let primary: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return formatter
    }()
}

struct LocationsResponse: Decodable {
    var stations: [APIStation]
}

struct APIStation: Decodable {
    var id: String?
    var name: String
    var coordinate: APICoordinate?
    var distance: Double?
}

struct APICoordinate: Decodable {
    var type: String?
    var x: Double?
    var y: Double?
}

struct StationboardResponse: Decodable {
    var stationboard: [APIStationboardDeparture]
}

struct APIStationboardDeparture: Decodable {
    var category: String?
    var number: String?
    var name: String?
    var to: String?
    var stop: APIStop?
}

struct APIStop: Decodable {
    var departure: Date?
    var platform: String?
    var delay: Int?
    var prognosis: APIPrognosis?
}

struct APIPrognosis: Decodable {
    var departure: Date?
}

extension TransitStop {
    init?(apiStation: APIStation) {
        guard let id = apiStation.id, !id.isEmpty else { return nil }
        self.id = id
        self.name = apiStation.name
        if let latitude = apiStation.coordinate?.x, let longitude = apiStation.coordinate?.y {
            self.coordinate = Coordinate(latitude: latitude, longitude: longitude)
        } else {
            self.coordinate = nil
        }
        self.distance = apiStation.distance
    }
}

extension StationboardDeparture {
    init?(apiDeparture: APIStationboardDeparture) {
        guard let plannedDeparture = apiDeparture.stop?.departure else { return nil }
        let category = apiDeparture.category ?? ""
        let number = apiDeparture.number ?? apiDeparture.name ?? ""
        let destination = apiDeparture.to ?? "Unknown destination"
        self.id = [
            category,
            number,
            destination,
            String(plannedDeparture.timeIntervalSince1970)
        ].joined(separator: "-")
        self.category = category
        self.number = number
        self.destination = destination
        self.plannedDeparture = plannedDeparture
        self.realtimeDeparture = apiDeparture.stop?.prognosis?.departure
        self.platform = apiDeparture.stop?.platform
        self.delayMinutes = apiDeparture.stop?.delay
    }
}
