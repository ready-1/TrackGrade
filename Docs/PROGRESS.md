# Progress

## Current Phase

- Phase 6 — Release readiness and hardware verification follow-through

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
- The grading screen has now been refactored into a fixed landscape surface with no vertical scroll: compact device and pipeline telemetry flank a top-center LGG / Saturation state window, saturation sits above the trackballs, reset controls remain visible, and presets / secondary actions live in a slide-over drawer.
- The offline fixture-backed UI suite was updated for the drawer flow and now explicitly rotates the simulator to landscape before assertions, keeping the automated checks aligned with the app’s landscape-only product shape.
- A manual simulator sanity check confirmed the new static grading surface composes correctly in fixture mode without needing live ColorBox hardware.
- Phase 4 offline workflow is now implemented in the app shell: TrackGrade persists local snapshots in SwiftData, supports undo / redo history for grade changes, provides A/B scratch slots, and exposes snapshot save / recall through the secondary workflow drawer.
- The workflow drawer was reshaped into fixed Workflow / Presets / Device panels so the main grading surface stays static while secondary operations remain reachable without reintroducing scroll on the primary control surface.
- The `-ui-test-fixture` path now seeds SwiftData-backed fixture devices and snapshots instead of relying on in-memory-only snapshot state, so offline snapshot save / recall exercises the same persistence path as the real app.
- `xcodebuild test` now covers the full offline control-surface path: fixture launch, bypass, settings, preset save, snapshot save, and snapshot recall.
- `swift test` and `xcodebuild test` both passed again after the offline snapshot workflow and drawer validation refactor.
- Settings now includes a more release-ready About section with version, license, repository, and conduct-contact information, and the app bundle metadata now presents itself as `TrackGrade` version `0.1.0`.
- `Docs/ARCHITECTURE.md`, `Docs/USER-GUIDE.md`, and `Docs/COLOR-SCIENCE.md` now describe the implemented app shell, offline fixture mode, live `/v2` grading path, and current limitations instead of remaining placeholders.
- Phase 5 first pass is now in place offline: saved devices can be linked as gang peers, the focused grading surface broadcasts grade / bypass / false color / preset recall to those peers, and the fixture-backed UI suite verifies gang bypass mirroring across three seeded devices.
- The placeholder library sheet has been replaced with a real read-only device library browser backed by the live `/v2` library endpoints, fixture data, and mock-server coverage for 1D LUT, 3D LUT, matrix, image, and overlay assets.
- `swift test` now verifies mock library reads, and `xcodebuild test` now covers the fixture library browser flow in the iPad UI suite.
- The grading top bar now includes a distinct `Before / After` compare control that temporarily flips bypass and restores the original state when compare mode ends, keeping it separate from the persistent ColorBox bypass toggle required by the brief.
- `xcodebuild test` now includes a fixture-backed Before / After regression that proves compare mode flips bypass on and then restores the original state cleanly.
- The README now includes a real simulator screenshot captured from fixture mode, replacing the earlier screenshot placeholder and giving the public repo a truthful visual of the current grading surface.

## In-Flight Work

- Closing the remaining hardware-only validation gap around true simultaneous multi-touch feel, gesture sensitivity tuning, and final live ColorBox confirmation on an iPad paired to the box.
- Backfilling the remaining release-facing polish so the repo is ready for a cleaner public handoff.
- Choosing the next non-hardware polish slice after the library browser and Before / After workflow landed, with broader accessibility and release collateral still open.

## Blockers

- Real signing metadata is still pending Apple Developer account restoration, so placeholder bundle metadata remains in use for now.
- True simultaneous multi-touch interaction still requires manual validation on actual iPad hardware with the real ColorBox even though the offline fixture-backed UI suite is now in place.

## Next Steps

- Finish the remaining release-prep pass around launch / packaging polish and any final README cleanup.
- Run the manual checklist in `Docs/PHASE-2-TESTING.md` on an actual iPad in landscape with the ColorBox back online.
- Validate that the new static layout still feels balanced on real hardware and adjust spacing if any control surface regions feel cramped in hand.
- Tune trackball and saturation sensitivities against the live ColorBox if the hardware session exposes drift or over-travel.
- Validate the new gang workflow against multiple real ColorBoxes and adjust any sync/drift heuristics if the live session exposes edge cases.
- Fill the remaining offline feature gaps that do not need hardware, especially broader accessibility tightening, release-collateral cleanup, and launch / packaging polish.
- Decide whether the current offline-ready build is sufficient for a first packaged release after the real-hardware confirmation pass, or whether another polish round is still needed.
