import ActivityKit
import Foundation

nonisolated struct SessionActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable, Sendable {
        var value: String
        var unit: String
        var status: String
        var readingDate: Date?
        var sampleCount: Int
    }
    var sessionID: UUID
    var instrument: String
    var symbol: String
    var source: String
}
