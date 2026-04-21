# Progress

## Current Phase

- Phase 1 — Connectivity and state plumbing started

## Completed Items

- Step 1 complete: installed the full project brief in `Docs/BRIEF.md`.
- Step 2 complete: initialized `Docs/PROGRESS.md`, `Docs/DECISIONS.md`, and `Docs/OPEN-QUESTIONS.md`.
- Step 3 complete: replaced the boilerplate `README.md`, added repository hygiene and community files, and later switched the project license to Apache-2.0.
- Step 4 complete: scaffolded the app, package, directory layout, placeholder sources, and `TrackGrade.xcodeproj`.
- Step 5 complete: added GitHub Actions CI for `swift test` and `xcodebuild test`.
- Step 6 complete: added `Docs/API-MAPPING.md` with the OpenAPI fetch placeholder.
- Step 7 complete: verified `swift test`, `swift build --product MockColorBox`, and `xcodebuild test` all pass locally with the full Xcode toolchain.
- Phase 1 kickoff inputs recorded from the user, including the reference ColorBox IP and open-source/license decisions.

## In-Flight Work

- Fetching the live OpenAPI spec from the reference ColorBox and beginning device connectivity plumbing.

## Blockers

- The reference ColorBox at `172.29.14.51` is visible over Bonjour but is currently unreachable over HTTP from this Mac, so the live OpenAPI fetch is blocked pending device/network verification.
- Real signing metadata is still pending Apple Developer account restoration, so placeholder bundle metadata remains in use for now.

## Next Steps

- Fetch and commit the live ColorBox OpenAPI spec from `172.29.14.51`.
- Generate and wrap the API client surface needed for connectivity, pipeline actions, presets, and preview.
- Implement Phase 1 device discovery, manual add, auth storage, pipeline configuration, preview, presets, and connection resilience.
