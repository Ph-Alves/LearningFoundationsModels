import SwiftUI
import SwiftData
import FoundationModels

/// Flattens either a fully or partially generated challenge into optional fields the UI can render either way.
private struct ChallengeDisplay {
    var title: String?
    var instruction: String?
    var type: FrictionType?
    var difficulty: Int?
    var rationale: String?

    init(_ challenge: FrictionChallenge) {
        title = challenge.title
        instruction = challenge.instruction
        type = challenge.type
        difficulty = challenge.difficulty
        rationale = challenge.rationale
    }

    init(_ partial: FrictionChallenge.PartiallyGenerated) {
        title = partial.title
        instruction = partial.instruction
        type = partial.type
        difficulty = partial.difficulty
        rationale = partial.rationale
    }
}

struct TaskDetailView: View {
    let task: TaskItem

    @State private var engine = FrictionEngine()
    @State private var creativity: Double = 0.6

    var body: some View {
        List {
            Section("Task") {
                if !task.notes.isEmpty {
                    Text(task.notes)
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading) {
                    Text("Creativity")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(value: $creativity, in: 0.1...1.0)
                }
                availabilityMessage
            }

            resultSections

            if !task.savedChallenges.isEmpty {
                Section("Saved") {
                    ForEach(task.savedChallenges) { saved in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: saved.type.symbolName)
                                Text(saved.title).font(.headline)
                            }
                            Text(saved.instruction)
                                .font(.subheadline)
                        }
                    }
                }
            }
        }
        .navigationTitle(task.title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                generateButton
            }
        }
        .task {
            engine.prewarm(for: task)
        }
    }

    @ViewBuilder
    private var resultSections: some View {
        switch engine.state {
        case .idle:
            EmptyView()
        case .loading:
            Section {
                HStack {
                    ProgressView()
                    Text("Thinking about challenges...")
                }
            }
        case .streaming(let partial):
            if let analysis = partial.analysis {
                Section("Analysis") {
                    Text(analysis)
                }
            }
            let challenges = partial.challenges ?? []
            if !challenges.isEmpty {
                Section("Challenges") {
                    ForEach(Array(challenges.enumerated()), id: \.offset) { _, challenge in
                        challengeRow(ChallengeDisplay(challenge), canAccept: false)
                    }
                }
            }
        case .finished(let plan):
            Section("Analysis") {
                Text(plan.analysis)
            }
            Section("Challenges") {
                ForEach(plan.challenges.indices, id: \.self) { index in
                    challengeRow(ChallengeDisplay(plan.challenges[index]), canAccept: true)
                }
            }
        case .failed(let message):
            Section {
                Text(message)
                    .foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder
    private var generateButton: some View {
        switch engine.state {
        case .loading, .streaming:
            ProgressView()
        case .finished:
            Menu {
                Button("Generate again", systemImage: "arrow.clockwise") {
                    Task { await engine.generate(for: task, creativity: creativity) }
                }
                Button("Harder", systemImage: "flame") {
                    Task { await engine.requestHarder() }
                }
            } label: {
                Label("Generate", systemImage: "wand.and.stars")
            }
        default:
            Button {
                Task { await engine.generate(for: task, creativity: creativity) }
            } label: {
                Label("Generate friction", systemImage: "wand.and.stars")
            }
            .disabled(engine.availability != .available)
        }
    }

    @ViewBuilder
    private var availabilityMessage: some View {
        if case .unavailable(let reason) = engine.availability {
            Label(message(for: reason), systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func message(for reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .deviceNotEligible:
            return "This device isn't compatible with Apple Intelligence."
        case .appleIntelligenceNotEnabled:
            return "Enable Apple Intelligence in Settings to generate challenges."
        case .modelNotReady:
            return "The model is still being prepared on this device. Try again soon."
        @unknown default:
            return "Mental friction generation isn't available right now."
        }
    }

    @ViewBuilder
    private func challengeRow(_ challenge: ChallengeDisplay, canAccept: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if let type = challenge.type {
                    Image(systemName: type.symbolName)
                }
                Text(challenge.title ?? "Generating...")
                    .font(.headline)
                Spacer()
                if let difficulty = challenge.difficulty {
                    difficultyDots(difficulty)
                }
            }
            if let instruction = challenge.instruction {
                Text(instruction)
            }
            if let rationale = challenge.rationale {
                Text(rationale)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if canAccept,
               let title = challenge.title,
               let instruction = challenge.instruction,
               let type = challenge.type,
               let difficulty = challenge.difficulty,
               let rationale = challenge.rationale {
                Button("Save", systemImage: "checkmark.circle") {
                    save(title: title, instruction: instruction, type: type, difficulty: difficulty, rationale: rationale)
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private func difficultyDots(_ difficulty: Int) -> some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .fill(index < difficulty ? Color.orange : Color.gray.opacity(0.3))
                    .frame(width: 6, height: 6)
            }
        }
    }

    private func save(title: String, instruction: String, type: FrictionType, difficulty: Int, rationale: String) {
        let challenge = SavedChallenge(title: title, instruction: instruction, type: type, difficulty: difficulty, rationale: rationale)
        task.savedChallenges.append(challenge)
    }
}

#Preview {
    NavigationStack {
        TaskDetailView(task: TaskItem(title: "Swimming", notes: "30 minutes, Olympic pool"))
    }
    .modelContainer(for: TaskItem.self, inMemory: true)
}
