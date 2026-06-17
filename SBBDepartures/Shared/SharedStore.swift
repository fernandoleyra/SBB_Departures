import Foundation

final class SharedStore {
    static let shared = SharedStore()

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.decoder = JSONDecoder()
        self.fileURL = fileURL ?? Self.defaultFileURL()
    }

    func load() -> DeparturesStoreState {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return .empty()
        }

        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode(DeparturesStoreState.self, from: data)
        } catch {
            return .empty()
        }
    }

    func save(_ state: DeparturesStoreState) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(state)
        try data.write(to: fileURL, options: [.atomic])
    }

    private static func defaultFileURL() -> URL {
        if let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
            return appGroupURL.appendingPathComponent("DeparturesStore.json")
        }

        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return support.appendingPathComponent("SBBDepartures/DeparturesStore.json")
    }
}
