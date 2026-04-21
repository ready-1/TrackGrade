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

## 2026-04-21 — Adopt User Product Decisions for Phase 1 Kickoff

### Context

Phase 1 depends on concrete product and repository decisions that were still open at the end of Phase 0.

### Decision

- Keep placeholder signing metadata until the Apple Developer account is unlocked.
- Use the reference ColorBox at `172.29.14.51` for live API and firmware inspection.
- Switch the project license from MIT to Apache-2.0.
- Treat Library import from the Files app as in-scope for v1.
- Keep the repository public during development.
- Confirm the product name as `TrackGrade`.
- Accept a placeholder app icon for now.
- Publish `info@getready1.com` as the Code of Conduct contact.

### Consequences

- Repository-facing materials must reflect Apache-2.0 instead of MIT.
- Bundle identifiers and signing settings may remain placeholder values until account access is restored.
- Phase 1 can proceed with live device inspection and OpenAPI capture using the supplied ColorBox endpoint.
