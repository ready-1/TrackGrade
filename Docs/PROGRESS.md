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
- Phase 1 connectivity foundation complete in `TrackGradeCore`: the handwritten ColorBox API wrapper, `DeviceManager`, mock-server contract, and integration tests now cover auth, pipeline config, toggles, presets, preview fetch, and reconnect behavior.
- Phase 1 app shell now includes a SwiftData-backed device list, Keychain-backed credentials, a Bonjour discovery sidebar, manual add by IP, preview display, preset controls, pipeline toggles, and a reconnect banner.
- `MockColorBox` now publishes a Bonjour `_http._tcp` service and was verified locally with `dns-sd` using the instance name `MockColorBox-BonjourCheck`.
- The live ColorBox OpenAPI spec was fetched successfully from the hardware and committed under `Docs/openapi-colorbox.json` and `Docs/openapi-colorbox.yaml`.
- TrackGrade now uses the generated `/v2` client for connect-time reads, preview decoding, preset listing, pipeline-node configuration, and bypass on hardware-compatible paths.
- `MockColorBox` now serves the matching `/v2` read surface plus `/v2/routing` and `/v2/pipelineStages` writes so the generated client path is exercised in package tests.
- The reference ColorBox at `172.29.14.51` reports `authenticationEnable: false`, so the current hardware can be exercised without credentials while the transport still preserves future API-key support.

## In-Flight Work

- Validating the new app shell against live hardware parity and replacing the remaining provisional false-color and preset-mutation routes with verified `/v2` operations.

## Blockers

- Real signing metadata is still pending Apple Developer account restoration, so placeholder bundle metadata remains in use for now.
- The real device spec has not yet revealed a dedicated false-color control route matching the brief.
- The live `/v2` contract has not yet yielded a verified preset save / recall / delete mapping for TrackGrade.

## Next Steps

- Exercise the current app shell against the real ColorBox using the new generated `/v2` read path and selected write path.
- Resolve live preset mutation semantics and the false-color control path.
- Add API-key entry and persistence to the app UI before targeting authenticated hardware.
- Verify the iPad app discovery flow end-to-end against the Bonjour-advertised `MockColorBox`.
- Re-map LUT upload to the real `/v2/upload` and related library-selection endpoints.
