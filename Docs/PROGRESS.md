# Progress

## Current Phase

- Phase 2 — Custom controls verification

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
- Device-native preset save for the dynamic grade path is now live-verified on firmware `3.0.0.24`: TrackGrade first calls `POST /v2/saveDynamicLutRequest`, then stores the `systemPreset`, then sets the user-visible preset name.
- The user confirmed that presets must live on the ColorBox and that the iPad should be treated as ephemeral, so TrackGrade will not rely on local-only preset persistence for the MVP.
- Phase 1 acceptance checks are green locally: `swift test` and `xcodebuild test` both passed after the device-native preset-save persistence fix.
- Phase 2 started with shared trackball mapping helpers that round-trip between touch control state and the current direct `pipelineStages` grade representation; package tests cover identity, clamping, and representative control-state round trips.
- The temporary slider-based grade card has been replaced with a touch-native Phase 2 control surface: three trackballs with independent ball/ring gesture regions, a saturation roller, numeric tap-to-edit rows, double-tap reset affordances, and a settings sheet for sensitivity/haptics tuning.
- The app target now compiles the UIKit touch bridge, settings feature, and haptics coordinator, and both `swift test` and `xcodebuild test` pass with the new control-surface code in place.
- TrackGrade now includes an offline `-ui-test-fixture` launch mode that seeds an in-memory ColorBox device, enabling app-level verification without direct hardware access.
- `TrackGrade.xcodeproj` now contains a real `TrackGradeUITests` target, and `xcodebuild test` covers fixture-backed launch, bypass toggle, settings-sheet launch, and preset-save flows on the iPad simulator.
- `Docs/PHASE-2-TESTING.md` now records the offline fixture path, simulator command, and the remaining manual checklist for simultaneous multi-touch and hardware feel validation.
- `App/Info.plist` now includes placeholder `UILaunchScreen` metadata so the iPad app shell stays ahead of the simulator launch-screen requirement.

## In-Flight Work

- Closing the remaining Phase 2 acceptance gap around true simultaneous multi-touch and real-device feel, which XCUITest still cannot validate end to end on its own.
- Applying the first round of layout feedback from live UI review:
  - remove vertical scrolling and keep the grading interface static in landscape
  - collapse telemetry into compact regions instead of large stacked cards
  - allow bypass, presets, and similar secondary actions to move into a drawer
  - move the LGG/S state display into a smaller top-center window and use the side areas for secondary device telemetry
  - move saturation above the trackballs
  - make the LGG/S reset affordances clearly visible in the main layout

## Blockers

- Real signing metadata is still pending Apple Developer account restoration, so placeholder bundle metadata remains in use for now.
- True simultaneous multi-touch interaction still requires manual validation on actual iPad hardware even though the offline fixture-backed UI suite is now in place.

## Next Steps

- Refactor the grading screen into a fixed landscape layout with no vertical scroll.
- Compress the telemetry layout and promote the compact top-center LGG/S state window.
- Rework secondary actions such as bypass and presets into a drawer-oriented presentation if the static layout needs the space.
- Move the saturation control above the trackball row.
- Ensure reset controls for Lift / Gamma / Gain / Saturation are immediately visible and legible in the static layout.
- Run the manual checklist in `Docs/PHASE-2-TESTING.md` once an iPad and ColorBox are available together again.
- Tune the gesture surface against real hardware if any sensitivity adjustments emerge during manual grading.
- Decide whether Phase 2 acceptance is satisfied with the new offline UI suite plus manual multi-touch validation, or whether another automation pass is needed before moving on.
