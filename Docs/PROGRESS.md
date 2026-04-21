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
- Live preset mutation mapping is now verified and implemented: save uses `StoreEntry` + `SetUserName`, recall uses `RecallEntry`, and delete uses `DeleteEntry` through `/v2/libraryControl`.
- A follow-up false-color discovery pass across the live `/v2` contract and shipped device web bundles did not reveal a control path, so false color is now treated as unsupported/deferred on firmware `3.0.0.24`.
- The user confirmed that authentication will remain disabled on the reference ColorBox, so auth UI work is no longer on the critical path for Phase 1.
- TrackGrade now infers false-color support during device refresh and disables the UI control on known-unsupported firmware instead of presenting it as an always-available toggle.
- Integration coverage now includes a mock-backed unsupported-false-color case so the app keeps the device connected while surfacing capability loss cleanly.
- The user explicitly deferred live LUT import from this version, so it is no longer an MVP blocker for the current release target.
- MVP priorities are now ordered as: dynamic 3D LUT control plus saturation, preset save, bypass toggle, then everything else.
- TrackGrade now exposes app-facing Lift / Gamma / Gain and saturation controls that read from and write to `lut3d_1.colorCorrector` and `procAmp.sat` through `/v2/pipelineStages`.
- The new dynamic-grade control path passed `swift test`, `xcodebuild test`, and a live round-trip check on the reference ColorBox, including restoring the hardware back to baseline after verification.

## In-Flight Work

- Investigating how preset save should work for the MVP now that direct dynamic-stage controls are live but the current device-native preset path does not preserve those runtime grade values on the reference firmware.

## Blockers

- Real signing metadata is still pending Apple Developer account restoration, so placeholder bundle metadata remains in use for now.
- Device-native preset save is not preserving the dynamic grade values driven through `/v2/pipelineStages` on firmware `3.0.0.24`, even though `StoreEntry` / `RecallEntry` succeed without device-side errors.

## Next Steps

- Exercise the current app shell against the real ColorBox using the new generated `/v2` read path and selected write path.
- Decide whether the MVP preset requirement can be satisfied with TrackGrade-local presets / snapshots, or whether it must remain device-native despite the current firmware limitation.
- Keep bypass and preset UX aligned with the new MVP ordering once the preset direction is settled.
- Verify the iPad app discovery flow end-to-end against the Bonjour-advertised `MockColorBox`.
- Prepare a Phase 1 checkpoint once the remaining upload uncertainty is either resolved or carved out of the current phase scope.
