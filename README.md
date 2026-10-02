# Mental Friction

An iOS/macOS app that uses **Apple Foundation Models** (on-device LLM) to generate deliberate cognitive challenges for physical and routine tasks — making habits harder on the brain so the body can stay on autopilot.

## What it does

Given a task like *"5 km run"* or *"Swimming"*, the app generates a structured **Friction Plan**: five mental challenges (counting, memory, constraint, focus, discomfort, planning) tailored to that activity. Each challenge includes a title, an executable instruction, a difficulty rating (1–5), and a rationale. The user can save challenges they like, regenerate with higher difficulty, or tweak creativity.

## Key concepts

| Concept | Description |
|---|---|
| **Mental friction** | A deliberate cognitive obstacle added to a routine task to exercise the brain without changing the physical activity. |
| **FrictionPlan** | The full LLM response: a brief analysis + five challenges. |
| **FrictionChallenge** | A single challenge with title, instruction, type, difficulty and rationale. |
| **FrictionEngine** | `@Observable` class that drives the Foundation Models session and exposes streaming state to SwiftUI. |

## Tech stack

- **Swift / SwiftUI** — UI and navigation
- **Foundation Models** (`FoundationModels`) — on-device structured generation with `@Generable` and `@Guide`
- **SwiftData** — local persistence for tasks and saved challenges
- **Observation** — reactive state propagation from `FrictionEngine` to views

## Requirements

- Xcode 26+
- iOS 26 / macOS 26 (Tahoe) or later
- Apple Intelligence enabled on-device

## Running

1. Open `testingFoundations.xcodeproj` in Xcode.
2. Select a real device (simulator does not support on-device models).
3. Build & run (`⌘R`).

> The first generation may be slow while the model loads. `FrictionEngine.prewarm(for:)` is called on task selection to reduce latency.
