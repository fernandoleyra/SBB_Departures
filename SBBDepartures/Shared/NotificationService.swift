import Foundation
import UserNotifications

final class NotificationService {
    private let center = UNUserNotificationCenter.current()
    private var lastNotificationByFavorite: [UUID: Date] = [:]

    func requestPermission() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    func evaluate(
        snapshots: [DepartureSnapshot],
        favorites: [FavoriteTransport],
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        let favoriteById = Dictionary(uniqueKeysWithValues: favorites.map { ($0.id, $0) })

        for snapshot in snapshots {
            guard let favorite = favoriteById[snapshot.favoriteId], favorite.alerts.enabled else { continue }
            guard shouldNotify(snapshot: snapshot, favorite: favorite, now: now, calendar: calendar) else { continue }
            lastNotificationByFavorite[favorite.id] = now
            send(snapshot: snapshot, favorite: favorite)
        }
    }

    private func shouldNotify(
        snapshot: DepartureSnapshot,
        favorite: FavoriteTransport,
        now: Date,
        calendar: Calendar
    ) -> Bool {
        let alert = favorite.alerts
        let hour = calendar.component(.hour, from: now)
        if isQuietHour(hour: hour, start: alert.quietStartHour, end: alert.quietEndHour) {
            return false
        }

        let walkMinutes = favorite.walkMinutes ?? 0
        let minutes = DepartureLogic.minutesUntil(snapshot.effectiveDeparture, now: now)
        guard minutes <= alert.leadMinutes + walkMinutes, minutes >= walkMinutes else {
            return false
        }

        if let last = lastNotificationByFavorite[favorite.id],
           now.timeIntervalSince(last) < TimeInterval(alert.repeatSuppressionMinutes * 60) {
            return false
        }

        return true
    }

    private func isQuietHour(hour: Int, start: Int, end: Int) -> Bool {
        if start == end { return false }
        if start < end { return hour >= start && hour < end }
        return hour >= start || hour < end
    }

    private func send(snapshot: DepartureSnapshot, favorite: FavoriteTransport) {
        let content = UNMutableNotificationContent()
        let minutes = DepartureLogic.minutesUntil(snapshot.effectiveDeparture)
        content.title = "\(snapshot.lineDisplay) in \(minutes) min"
        content.body = "\(favorite.stopName) to \(snapshot.destination)"
        if let platform = snapshot.platform, !platform.isEmpty {
            content.subtitle = "Platform \(platform)"
        }

        let request = UNNotificationRequest(
            identifier: "departure-\(favorite.id.uuidString)-\(snapshot.effectiveDeparture.timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        center.add(request)
    }
}
