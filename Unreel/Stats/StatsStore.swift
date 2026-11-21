import Foundation

enum BlockKind: String, Codable {
    case reels, explore, feed
}

struct DayStats: Codable, Equatable {
    var reelsBlocked = 0
    var exploreBlocked = 0
    var secondsUsed = 0
    var limitExtensions = 0

    var totalBlocked: Int { reelsBlocked + exploreBlocked }
}

struct DayEntry: Identifiable {
    let date: Date
    let stats: DayStats
    var id: Date { date }
}

/// On-device daily stats. Stored only in UserDefaults on the phone.
@MainActor
final class StatsStore: ObservableObject {
    @Published private(set) var days: [String: DayStats] = [:]

    private let storageKey = "dailyStats.v1"
    private var pendingSave = false

    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([String: DayStats].self, from: data) {
            days = decoded
        }
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .autoupdatingCurrent
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Local-time day key, e.g. "2026-11-21". Sorts in date order as a string.
    static func key(for date: Date) -> String { dayFormatter.string(from: date) }

    var today: DayStats { days[Self.key(for: Date())] ?? DayStats() }

    var allTimeBlocked: Int { days.values.reduce(0) { $0 + $1.totalBlocked } }

    /// The last `count` days including today, oldest first.
    func recentDays(_ count: Int = 7) -> [DayEntry] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        return (0..<count).reversed().compactMap { offset in
            guard let date = cal.date(byAdding: .day, value: -offset, to: start) else { return nil }
            return DayEntry(date: date, stats: days[Self.key(for: date)] ?? DayStats())
        }
    }

    func record(_ kind: BlockKind) {
        update {
            switch kind {
            case .reels: $0.reelsBlocked += 1
            case .explore: $0.exploreBlocked += 1
            case .feed: break
            }
        }
    }

    func addUsage(seconds: Int) {
        update { $0.secondsUsed += seconds }
    }

    func recordLimitExtension() {
        update { $0.limitExtensions += 1 }
    }

    private func update(_ change: (inout DayStats) -> Void) {
        let key = Self.key(for: Date())
        var day = days[key] ?? DayStats()
        change(&day)
        days[key] = day
        scheduleSave()
    }

    private func scheduleSave() {
        guard !pendingSave else { return }
        pendingSave = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.save()
        }
    }

    func save() {
        pendingSave = false
        // Keep 90 days of history.
        let cutoff = Self.key(for: Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date())
        days = days.filter { $0.key >= cutoff }
        if let data = try? JSONEncoder().encode(days) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
