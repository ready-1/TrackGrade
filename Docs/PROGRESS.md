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
- TrackGrade now ships with a real `LaunchScreen.storyboard`, replacing the earlier placeholder launch metadata and covering the release brief’s launch-screen requirement for the app target.
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
- Phase 3 core work is now implemented in `Core/ColorMath`: `CDLValues`, `TransferFunction`, `CubeLUT`, and `LUTBaker` cover linear-light CDL math, Rec.709 SDR / HLG transfer functions, `.cube` serialization, and `33^3` LUT baking.
- `DeviceManager` now includes a per-device last-write-wins `DynamicLUTUploadQueue`, giving TrackGrade the coalescing upload behavior required by the brief without blocking the UI on every intermediate touch sample.
- Mock-backed integration coverage now verifies both a full identity LUT upload and aggressive queue coalescing, proving that the newest LUT wins when uploads arrive faster than the device ingest path can drain them.
- `Core/ColorMath` automated line coverage is now `92.71%`, clearing the brief’s `>= 90%` Phase 3 target for the color-math module.
- The release-only `LUTBakerPerformanceTests` timing check passed locally with a `33^3` identity bake completing well under the brief’s `< 16 ms` threshold.
- `StoredColorBoxDevice` now persists a per-device working color space selection, and the settings sheet exposes `Rec.709 SDR` vs `Rec.709 HLG` as a real segmented control instead of a placeholder label.
- The app target now includes a real placeholder app icon asset catalog under `App/Assets.xcassets`, so the project no longer ships with the generic Xcode icon in simulator builds and future packaged builds.
- Device-native presets now have a more complete operator workflow: TrackGrade keeps a durable local thumbnail cache per device slot, shows preset thumbnails in the drawer, confirms recall before applying it, and exposes long-press rename / overwrite actions instead of only save / delete buttons.
- Settings now exports a shareable diagnostics report for the focused device, exposes in-app open-source notices, and the repo now includes a top-level `NOTICES.md`.
- Live hardware validation on firmware `3.0.0.24` found that `POST /v2/saveDynamicLutRequest` needs about one second of settle time after direct `PUT /v2/pipelineStages` grade changes before a preset save reliably captures the new state; TrackGrade now applies that delay on non-local hosts before saving a device-native preset.
- Preview controls are now closer to the brief: TrackGrade maps the thumbnail source toggle onto live `PUT /v2/routing` `previewTap` updates, supports preview auto-refresh from Settings, and opens an enlarged medium-sheet preview from the control surface while preserving the compact static main layout.
- The mock server and fixture mode now mirror preview source state, and automated coverage now verifies both preview source toggling and the enlarged preview presentation path.
- The fixture-backed static control surface now passes the focused `.hitRegion` accessibility audit, and the saved-device list accessibility contract was tightened so UI coverage can interact with real row-level device actions reliably.
- Live hardware verification on `172.29.14.51` confirmed that `POST /v2/upload` now materializes `3D LUT` library entries on firmware `3.0.0.24`, and that `SetUserName` plus `DeleteEntry` work against `library: "3D LUT"` for rename and cleanup.
- The library browser is now a full slot-aware management surface: every surfaced device library renders as a padded 16-slot section, including AMF, and supported asset kinds now expose import / replace / rename / delete actions from the iPad UI.
- TrackGrade now uses the live `POST /v2/upload` plus `PUT /v2/libraryControl` flow for 1D LUT, 3D LUT, matrix, image, and overlay asset management, while AMF remains browse-first because the hardware uses a separate multi-file upload path.
- Mock-server integration now covers upload / rename / delete library mutations, and the fixture-backed UI suite now covers empty-slot import affordances plus destructive library delete behavior.
- A fresh live hardware probe confirmed that the app’s multipart upload shape works as shipped: `application/octet-stream` uploads create device library entries, `SetUserName` updates both visible name and filename, and `DeleteEntry` cleans the slot back to empty.
- The package-side generated client now targets the live device correctly with a base URL of `http://host/v2` without a trailing slash, eliminating the broken `/v2//...` request shape that had been masking real hardware validation in `swift test`.
- TrackGrade now includes opt-in reversible live integration tests for grade / bypass / preview round-trips, preset lifecycle, and `3D LUT` library upload / rename / delete against the reference ColorBox, and those checks passed on `2026-04-22`.
- A follow-up live probe confirmed that TrackGrade can upload a `3D LUT` asset, point `lut3d_1` at a library slot with `dynamic = false`, and read that stage configuration back successfully. The reference test box appears to have no active signal right now, so identical preview hashes for `INPUT` and `OUTPUT` are no longer treated as negative evidence against the uploaded-LUT path; visual confirmation just still needs an active feed.
- The grading shell now uses a closable overlay device drawer instead of a permanent split view, the main color surface is compressed to a single static landscape page, duplicated device telemetry has been removed from the primary surface, and lower-priority ColorBox metadata now lives in the drawer’s device panel.
- The device drawer now has a reliable dismiss path for both users and automation, device-action buttons are stacked so labels remain readable on iPad, and the fixture UI suite now covers the revised drawer and gang-selection flow.
- TrackGrade now supports AMF library import through the dedicated multi-file `/v2/uploadMultiple` path in the app, client, and mock server, with package coverage proving AMF package upload and delete behavior offline.
- A new live design reference from the user now sets the preferred visual direction for the grading surface: compact, business-like, control-first, with a centered status window, minimal chrome, and drawer-based access to secondary device details.
- The main grading surface has now been reshaped toward that compact hardware-panel direction: matte industrial styling, a small centered LGG / saturation state window, compact preview and status side panels, visually dominant trackballs, and reduced on-surface telemetry while keeping the drawer-based workflow intact.
- The compact-surface pass now presents direct Lift / Gamma / Gain control-state values (X / Y / Bias) instead of derived RGB telemetry in the center display, removes more duplicated information from the primary surface, and makes Ball / Bias / Saturation reset affordances explicit on the control layer.
- The full simulator suite passed again after hardening the library delete UI test path for the current iOS simulator menu presentation behavior, so the compact-surface pass is now verified end-to-end.
- The opt-in live integration tests now preflight `http://<host>/v2/buildInfo` with a short timeout and skip quickly when the reference ColorBox is unreachable, preventing long hangs when the network path is down.
- A hardware debugging pass against the older working `colobox-control` prototype showed that real-time grade changes on ColorBox are driven by a baked dynamic-LUT payload sent over `ws://<host>:5000`, not by `PUT /v2/pipelineStages` alone.
- TrackGrade now bakes the current Lift / Gamma / Gain / Saturation state into a `33^3` LUT, uploads it over the ColorBox dynamic-LUT WebSocket transport for real hosts, and still mirrors the same values into `pipelineStages` for device readback, preset-save compatibility, and app synchronization.
- The new live dynamic-grade path is verified on the reference ColorBox: `TRACKGRADE_LIVE_COLORBOX_HOST=172.29.14.51 swift test --filter TrackGradeIntegrationTests/testLiveColorBoxRoundTripsGradeBypassAndPreview` passed on `2026-04-22`, and the mock-backed integration suite now asserts that grade writes produce a dynamic-LUT upload.
- The full Xcode simulator suite passed again after the transport fix; one preview-overlay UI test remains intentionally skipped because the current iOS simulator build is flaky for that interaction even though the feature remains available in the app for manual verification.

## In-Flight Work

- Closing the remaining hardware-only validation gap around true simultaneous multi-touch feel, gesture sensitivity tuning, and final live ColorBox confirmation on an iPad paired to the box.
- Backfilling the remaining release-facing polish so the repo is ready for a cleaner public handoff.
- Choosing the next non-hardware polish slice after library management, Before / After workflow, and Phase 3 color-math core landed, with broader accessibility and release collateral still open.
- Using the restored production network window to finish as much live hardware validation as possible beyond the now-confirmed preset timing fix.
- Using the restored production network window to finish the remaining iPad-only touch validation and any extra contract probing now that repeatable live backend tests exist in the repo.
- Finishing the release-facing accessibility and documentation pass now that preview controls, diagnostics export, notices, and preset workflow polish are in place.
- Re-running live hardware probes for `/v2/uploadMultiple` and any remaining library paths while the reference ColorBox is reachable again.

## Blockers

- Real signing metadata is still pending Apple Developer account restoration, so placeholder bundle metadata remains in use for now.
- True simultaneous multi-touch interaction still requires manual validation on actual iPad hardware with the real ColorBox even though the offline fixture-backed UI suite is now in place.
- The current release build still relies on placeholder icon/signing/package identity details until the Apple account is available again.
- Visual confirmation of a library-selected uploaded LUT still needs an active signal on the reference ColorBox, because the current test box appears to be idle and therefore produces identical `INPUT` / `OUTPUT` preview hashes.
- Live AMF verification is still pending because `/v2/uploadMultiple` has not yet been re-probed successfully against the current reachable reference box.

## Next Steps

- Finish the remaining release-prep pass around packaging polish, app-icon work, and any final README cleanup.
- Run the manual checklist in `Docs/PHASE-2-TESTING.md` on an actual iPad in landscape with the ColorBox back online.
- Validate that the revised static layout and drawer dismissal feel balanced on real hardware and adjust spacing if any control surface regions feel cramped in hand.
- Validate that the new control-state center window and explicit reset labels read clearly at normal iPad operating distance without reintroducing visual clutter.
- Re-test the corrected live grade path on the iPad against bars and the downstream scope now that TrackGrade is driving the dynamic-LUT transport instead of relying on `pipelineStages` alone.
- Tune trackball and saturation sensitivities against the live ColorBox if the hardware session exposes drift or over-travel.
- Validate the new gang workflow against multiple real ColorBoxes and adjust any sync/drift heuristics if the live session exposes edge cases.
- Fill the remaining offline feature gaps that do not need hardware, especially broader accessibility tightening, release-collateral cleanup, and app-icon / packaging polish.
- Finish the remaining release-collateral cleanup now that `NOTICES.md`, diagnostics export, and in-app notices are in place.
- Re-run the manual hardware checklist with attention to preset-save timing, now that the app includes a one-second settle before `saveDynamicLutRequest`.
- Re-run the new opt-in live integration tests whenever the reference firmware or network environment changes so hardware regressions are caught before manual iPad time.
- Extend the passing accessibility audit work into broader VoiceOver / Dynamic Type / contrast verification beyond the current hit-region pass.
- Validate AMF import against the real ColorBox as soon as the reference box is reachable again, using the committed official ACES sample package.
- Decide whether the current offline-ready build is sufficient for a first packaged release after the real-hardware confirmation pass, or whether another polish round is still needed.
