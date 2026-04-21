# Contributing to TrackGrade

Thanks for your interest in contributing to TrackGrade.

## Before You Start

- Read `Docs/BRIEF.md` for the project specification and phase gates.
- Read `Docs/PROGRESS.md`, `Docs/DECISIONS.md`, and `Docs/OPEN-QUESTIONS.md` before starting work.
- Keep changes aligned with the active phase. Do not skip ahead of accepted milestones.

## Development Setup

1. Install Xcode 16 or later with Swift 6 support.
2. Clone the repository.
3. Open `TrackGrade.xcodeproj` in Xcode for app development.
4. Use `swift test` for package-based tests.
5. Use `swift run MockColorBox` when working on mocked device integration.

## Workflow Expectations

- Prefer small, focused pull requests.
- Keep documentation current alongside code changes.
- Record architectural choices in `Docs/DECISIONS.md`.
- Record unresolved product or engineering questions in `Docs/OPEN-QUESTIONS.md`.
- Update `Docs/PROGRESS.md` at the end of each working session.
- Add or update tests when behavior changes, especially in `Core/ColorMath/`.

## Commit Guidelines

- Commit early and often with descriptive messages.
- Do not mix unrelated changes in a single commit.
- Keep the repository in a buildable state whenever possible.

## Pull Requests

Please include:

- a clear summary of the change
- links to related issues or decisions
- notes on testing performed
- screenshots or screen recordings for UI changes when available

## Code Style

- Swift 6 with strict concurrency
- SwiftUI with `@Observable` for state where appropriate
- No third-party HTTP libraries
- Prefer standard Apple frameworks and documented project patterns

## Questions

If requirements are unclear, do not guess. Add the question to `Docs/OPEN-QUESTIONS.md` and surface it in the pull request or issue.
