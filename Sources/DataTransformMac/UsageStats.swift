import Foundation

@MainActor
final class UsageStats: ObservableObject {
    @Published private(set) var counts: [TransformAction: Int]
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.counts = TransformAction.allCases.reduce(into: [:]) { partialResult, action in
            partialResult[action] = defaults.integer(forKey: Self.key(for: action))
        }
    }

    func count(for action: TransformAction) -> Int {
        counts[action] ?? 0
    }

    func increment(action: TransformAction) {
        let newValue = (counts[action] ?? 0) + 1
        counts[action] = newValue
        defaults.set(newValue, forKey: Self.key(for: action))
    }

    private static func key(for action: TransformAction) -> String {
        "usage_stats_\(action.rawValue)"
    }
}
