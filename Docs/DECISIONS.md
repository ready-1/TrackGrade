# Decisions

## 2026-04-21 — Adopt TrackGrade Brief v1.0 as Project Specification

### Context

The repository needs a single durable source of truth for scope, architecture, phased delivery, and acceptance criteria before implementation begins.

### Decision

Adopt `Docs/BRIEF.md` (TrackGrade brief v1.0, dated 2026-04-21) as the project specification and phase gate reference.

### Consequences

- Implementation must follow the phased plan and hard acceptance criteria in the brief.
- Ambiguities and unresolved product choices must be tracked in `Docs/OPEN-QUESTIONS.md` instead of being silently assumed.
- Session continuity starts by rereading the brief and living documents from disk.

## 2026-04-21 — Use a Separate SwiftPM Core Package Alongside the iPad App Project

### Context

Phase 0 requires an iPad app target, a separate `TrackGradeCore` Swift package for core modules, and a separate `MockColorBox` executable target that can build on macOS.

### Decision

Use a repo-root Swift package named `TrackGradeCore` for the `Core/` modules and `MockServer/` executable target, while keeping the iPad app in `TrackGrade.xcodeproj`.

### Consequences

- `swift test` and `swift run MockColorBox` validate the package and mock-server side independently of the iPad app.
- `xcodebuild test` validates the iPad app target and Xcode project configuration separately.
- The app target can begin with minimal UI scaffolding while the core package evolves in parallel under test.
