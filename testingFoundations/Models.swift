import Foundation
import FoundationModels
import SwiftData

/// The category of mental friction a challenge introduces.
@Generable
enum FrictionType: String, CaseIterable, Codable, Sendable {
    case counting
    case memory
    case constraint
    case focus
    case discomfort
    case planning

    var label: String {
        switch self {
        case .counting: "Counting"
        case .memory: "Memory"
        case .constraint: "Constraint"
        case .focus: "Focus"
        case .discomfort: "Discomfort"
        case .planning: "Planning"
        }
    }

    var symbolName: String {
        switch self {
        case .counting: "number"
        case .memory: "brain.head.profile"
        case .constraint: "hand.raised"
        case .focus: "scope"
        case .discomfort: "flame"
        case .planning: "map"
        }
    }
}

/// A friction challenge the person accepted and saved to a task.
struct SavedChallenge: Codable, Identifiable, Hashable {
    var id: UUID
    var title: String
    var instruction: String
    var type: FrictionType
    var difficulty: Int
    var rationale: String

    init(id: UUID = UUID(), title: String, instruction: String, type: FrictionType, difficulty: Int, rationale: String) {
        self.id = id
        self.title = title
        self.instruction = instruction
        self.type = type
        self.difficulty = difficulty
        self.rationale = rationale
    }
}

/// A task the person wants to add mental friction to, like "Swimming".
@Model
final class TaskItem {
    var title: String
    var notes: String
    var createdAt: Date
    var savedChallenges: [SavedChallenge]

    init(title: String, notes: String = "") {
        self.title = title
        self.notes = notes
        self.createdAt = Date()
        self.savedChallenges = []
    }
}
