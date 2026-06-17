import SwiftUI
import WidgetKit

struct DeparturesEntry: TimelineEntry {
    var date: Date
    var state: DeparturesStoreState
}

struct DeparturesProvider: TimelineProvider {
    func placeholder(in context: Context) -> DeparturesEntry {
        DeparturesEntry(date: Date(), state: .empty())
    }

    func getSnapshot(in context: Context, completion: @escaping (DeparturesEntry) -> Void) {
        completion(DeparturesEntry(date: Date(), state: SharedStore.shared.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DeparturesEntry>) -> Void) {
        let state = SharedStore.shared.load()
        let entry = DeparturesEntry(date: Date(), state: state)
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(60))))
    }
}

struct DeparturesWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: DeparturesEntry

    private var activeProfile: LocationProfile? {
        entry.state.profiles.first { $0.id == entry.state.activeProfileId }
    }

    private var visibleSnapshots: [DepartureSnapshot] {
        let limit = family == .systemSmall ? 3 : 6
        return Array(entry.state.snapshots
            .filter { $0.profileId == entry.state.activeProfileId && $0.effectiveDeparture >= Date().addingTimeInterval(-60) }
            .sorted { $0.effectiveDeparture < $1.effectiveDeparture }
            .prefix(limit))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(activeProfile?.name ?? "SBB", systemImage: "tram.fill")
                    .font(.headline)
                Spacer()
                if DepartureLogic.isStale(lastRefresh: entry.state.lastRefresh) {
                    Image(systemName: "clock.badge.exclamationmark")
                        .foregroundStyle(.orange)
                }
            }

            if visibleSnapshots.isEmpty {
                Spacer()
                Text("No departures")
                    .font(.subheadline.weight(.medium))
                Text("Add favorites in the menu bar app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ForEach(visibleSnapshots) { snapshot in
                    WidgetDepartureRow(snapshot: snapshot)
                }
                Spacer(minLength: 0)
            }

            if let lastRefresh = entry.state.lastRefresh {
                Text("Updated \(DepartureDateFormatting.relativeFormatter.localizedString(for: lastRefresh, relativeTo: entry.date))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .containerBackground(.background, for: .widget)
    }
}

struct WidgetDepartureRow: View {
    var snapshot: DepartureSnapshot

    var body: some View {
        HStack(spacing: 8) {
            Text("\(DepartureLogic.minutesUntil(snapshot.effectiveDeparture))")
                .font(.headline.monospacedDigit())
                .frame(width: 30, alignment: .trailing)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(snapshot.lineDisplay)
                        .font(.subheadline.weight(.semibold))
                    Text(snapshot.destination)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                HStack(spacing: 6) {
                    Text(DepartureDateFormatting.timeFormatter.string(from: snapshot.effectiveDeparture))
                    if let delay = snapshot.delayMinutes, delay > 0 {
                        Text("+\(delay)").foregroundStyle(.red)
                    }
                    if let platform = snapshot.platform, !platform.isEmpty {
                        Text("Pl. \(platform)")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
    }
}

@main
struct DeparturesWidgetBundle: WidgetBundle {
    var body: some Widget {
        DeparturesWidget()
    }
}

struct DeparturesWidget: Widget {
    let kind = "DeparturesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DeparturesProvider()) { entry in
            DeparturesWidgetView(entry: entry)
                .padding()
        }
        .configurationDisplayName("SBB Departures")
        .description("See your next favorite departures for the active profile.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
