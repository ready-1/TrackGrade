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

## In-Flight Work

- Validating the new app shell against live hardware parity and replacing the provisional transport layer with generated code from the real `/v2` spec.

## Blockers

- Real signing metadata is still pending Apple Developer account restoration, so placeholder bundle metadata remains in use for now.
- The live OpenAPI contract uses `X-API-KEY` auth instead of Basic Auth, so the current credential model is incomplete for mutating calls.
- The real device spec has not yet revealed a dedicated false-color control route matching the brief.

## Next Steps

- Integrate `swift-openapi-generator` against the committed live spec and get the generated client compiling in the package.
- Decide how TrackGrade should acquire and store the `X-API-KEY` required by secured write operations.
- Re-map pipeline, preset, preview, and LUT-upload flows to the real `/v2` endpoints before replacing the handwritten wrapper.
- Verify the iPad app discovery flow end-to-end against the Bonjour-advertised `MockColorBox`.
- Exercise the app shell against the mock server and real hardware to confirm Phase 1 acceptance on-device.
