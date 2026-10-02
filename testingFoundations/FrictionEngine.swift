import Foundation
import FoundationModels
import Observation

/// One mental-friction challenge suggested for a task.
@Generable
struct FrictionChallenge: Sendable {
    @Guide(description: "Short challenge title, up to 6 words")
    var title: String

    @Guide(description: "Concrete, executable instruction to follow during the task, no extra equipment")
    var instruction: String

    @Guide(description: "Category of the mental friction type the challenge exercises")
    var type: FrictionType

    @Guide(description: "Difficulty of the mental friction, from 1 (light) to 5 (extreme)", .range(1...5))
    var difficulty: Int

    @Guide(description: "One-sentence explanation of why this challenge increases mental friction")
    var rationale: String
}

/// The full plan the model proposes for a task.
@Generable
struct FrictionPlan: Sendable {
    @Guide(description: "Brief analysis, in 1-2 sentences, of where the task's main mental effort lies")
    var analysis: String

    @Guide(description: "Mental friction challenges for the task, varying the types between them", .count(5))
    var challenges: [FrictionChallenge]
}

/// Read-only context handed to tools so they don't need to touch the SwiftData model directly.
struct FrictionContext: Sendable {
    var taskTitle: String
    var taskNotes: String
    var existingChallengeTitles: [String]
}

/// Lets the model check which challenges were already accepted for this task, so it can avoid repeating itself.
struct ExistingChallengesTool: Tool {
    let name = "existingChallenges"
    let description = "Returns the titles of the mental friction challenges already accepted for this task, to avoid repetition."
    let context: FrictionContext

    func call(arguments: GeneratedContent) async throws -> String {
        guard !context.existingChallengeTitles.isEmpty else {
            return "No challenge has been accepted for this task yet."
        }
        return context.existingChallengeTitles.joined(separator: "; ")
    }
}

private let frictionInstructions = """
You are a coach who designs "mental friction" for physical or routine tasks.

Mental friction is a deliberate cognitive obstacle — counting, memorization, sensory restriction, attentional focus, controlled discomfort, or planning — that the person adds to the task to exercise the brain, not the body.

Rules:
- Physical safety always comes first: never propose anything that increases risk of injury, drowning, accident, or dangerous distraction.
- Be specific to the context of the received task; generic challenges don't work.
- Before proposing, use the "existingChallenges" tool to avoid repeating challenges already accepted.
- Vary the types (counting, memory, restriction, focus, discomfort, planning) between the challenges of a single plan.
- Each instruction must be executable in a few words, with no extra equipment.

Example for the task "5km run":
- Counting: "Count your steps in blocks of 7 until you lose count, and restart from zero without getting frustrated."
- Memory: "Memorize 5 random words before starting and recite them in reverse order during the last kilometer."
"""

/// Drives a Foundation Models session that turns a task into a plan of mental-friction challenges.
@Observable
final class FrictionEngine {
    enum State {
        case idle
        case loading
        case streaming(FrictionPlan.PartiallyGenerated)
        case finished(FrictionPlan)
        case failed(String)
    }

    private(set) var state: State = .idle

    private var session: LanguageModelSession?

    /// Whether the on-device model is ready to use right now.
    var availability: SystemLanguageModel.Availability {
        SystemLanguageModel.default.availability
    }

    /// Loads the model into memory ahead of time, so the first real request feels faster.
    func prewarm(for task: TaskItem) {
        guard availability == .available else { return }
        let activeSession = makeSession(context: makeContext(for: task))
        session = activeSession
        activeSession.prewarm(promptPrefix: Prompt("Task: \(task.title)."))
    }

    func generate(for task: TaskItem, creativity: Double) async {
        state = .loading

        // TEMPORARY DIAGNOSTIC round 2: @Generable structured generation, but NO tools —
        // isolates whether it's specifically tool calling that fails.
        let activeSession = LanguageModelSession(instructions: frictionInstructions)
        session = activeSession

        let prompt = """
        Task: \(task.title)
        Notes: \(task.notes.isEmpty ? "none" : task.notes)
        Generate the mental friction plan for this task.
        """

        var options = GenerationOptions()
        options.temperature = creativity

        await stream(activeSession.streamResponse(to: prompt, generating: FrictionPlan.self, options: options))
    }

    /// Reuses the same session, asking the model to escalate the difficulty of the current plan.
    func requestHarder() async {
        guard let activeSession = session else { return }
        state = .loading
        await stream(
            activeSession.streamResponse(
                to: "Redo the plan keeping the same format, but make each challenge noticeably harder.",
                generating: FrictionPlan.self
            )
        )
    }

    // MARK: - Streaming

    private func stream(_ responseStream: sending LanguageModelSession.ResponseStream<FrictionPlan>) async {
        do {
            for try await snapshot in responseStream {
                state = .streaming(snapshot.content)
            }
            let response = try await responseStream.collect()
            state = .finished(response.content)
        } catch {
            state = .failed(Self.message(for: error))
        }
    }

    // MARK: - Session setup

    private func makeContext(for task: TaskItem) -> FrictionContext {
        FrictionContext(
            taskTitle: task.title,
            taskNotes: task.notes,
            existingChallengeTitles: task.savedChallenges.map(\.title)
        )
    }

    private func makeSession(context: FrictionContext) -> LanguageModelSession {
        LanguageModelSession(
            model: .default,
            tools: [ExistingChallengesTool(context: context)],
            instructions: frictionInstructions
        )
    }

    private static func message(for error: Error) -> String {
        // The framework sometimes wraps the real error inside a ToolCallError
        // (for example, when it fails to load the model to decide whether to call the tool).
        if let toolCallError = error as? LanguageModelSession.ToolCallError {
            return message(for: toolCallError.underlyingError)
        }

        if #available(iOS 27.0, macOS 27.0, visionOS 27.0, *), let modelError = error as? LanguageModelError {
            switch modelError {
            case .contextSizeExceeded:
                return "The conversation got too large. Tap \"Generate friction\" again to start over."
            case .guardrailViolation:
                return "The task's content couldn't be processed for safety reasons. Try rephrasing the title or notes."
            case .unsupportedLanguageOrLocale:
                return "The current language isn't supported by the model on this device."
            case .rateLimited:
                return "Too many requests in a short time. Wait a moment and try again."
            case .refusal:
                return "The model couldn't generate a response for this task. Try rephrasing."
            default:
                return "Couldn't generate the challenges right now. (\(modelError.localizedDescription)) [debug: \(String(describing: modelError))]"
            }
        }

        if #available(iOS 27.0, macOS 27.0, visionOS 27.0, *), let systemError = error as? SystemLanguageModel.Error {
            switch systemError {
            case .assetsUnavailable:
                return "The model is still being prepared on this device, or Apple Intelligence was disabled. Check Settings and try again. [debug: \(String(describing: systemError))]"
            @unknown default:
                return "Couldn't generate the challenges right now. (\(systemError.localizedDescription)) [debug: \(String(describing: systemError))]"
            }
        }

        // iOS 26 (before LanguageModelError existed) throws this type instead.
        if let generationError = error as? LanguageModelSession.GenerationError {
            switch generationError {
            case .exceededContextWindowSize:
                return "The conversation got too large. Tap \"Generate friction\" again to start over."
            case .guardrailViolation:
                return "The task's content couldn't be processed for safety reasons. Try rephrasing the title or notes."
            case .unsupportedLanguageOrLocale:
                return "The current language isn't supported by the model on this device."
            case .rateLimited:
                return "Too many requests in a short time. Wait a moment and try again."
            case .refusal:
                return "The model couldn't generate a response for this task. Try rephrasing."
            case .assetsUnavailable:
                return "The model is still being prepared on this device. Try again soon. [debug: \(String(describing: generationError))]"
            case .decodingFailure, .unsupportedGuide:
                return "The model generated a response in an unexpected format. Tap \"Generate friction\" again."
            @unknown default:
                return "Couldn't generate the challenges right now. (\(generationError.localizedDescription)) [debug: \(String(describing: generationError))]"
            }
        }

        let description = error.localizedDescription
        if description.localizedCaseInsensitiveContains("asset") {
            return "The on-device model isn't available right now (model resources unavailable). Check that Apple Intelligence is enabled in Settings, that the device isn't in Low Power Mode, and try again in a bit. [debug: \(String(describing: error))]"
        }

        return "Couldn't generate the challenges right now. (\(description)) [debug: \(String(describing: error))]"
    }
}
