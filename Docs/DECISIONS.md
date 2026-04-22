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

## 2026-04-21 — Keep a Handwritten ColorBox Wrapper Until the Live OpenAPI Spec Can Be Fetched

### Context

The brief requires a generated OpenAPI client, but the reference ColorBox is currently visible only through Bonjour and ARP while direct HTTP access from this Mac still fails. Phase 1 connectivity work still needs to continue against the mock server and the iPad app shell.

### Decision

Implement a thin handwritten `ColorBoxAPIClient` and matching mock-server routes now, with the explicit intent to replace the transport layer with `swift-openapi-generator` output once `Docs/openapi-colorbox.json` can be fetched from the live device.

### Consequences

- Phase 1 can keep moving despite the live OpenAPI fetch blocker.
- `Docs/API-MAPPING.md` must stay explicit about which provisional routes are in use so the eventual generator swap is mechanical.
- A later phase must reconcile any route or schema differences discovered from the real device specification.

## 2026-04-21 — Compile the Shared Core Sources Into the App Target Until Local Package Wiring Is Automated

### Context

`TrackGradeCore` exists as the source-of-truth Swift package, but the hand-maintained Xcode project started without local package-product integration. Phase 1 required the app target to use the shared `DeviceManager` and API models immediately.

### Decision

Add the necessary `Core/ColorBoxAPI` and `Core/DeviceManager` source files directly to the `TrackGrade` app target while keeping the repo-root Swift package as the canonical package build surface.

### Consequences

- The app target and the Swift package currently compile the same shared core sources from disk.
- Package tests remain the fastest way to validate the transport and mock-server layer, while `xcodebuild test` validates the iPad app shell separately.
- The project should later be upgraded to consume the local package product directly to reduce duplicate target wiring.

## 2026-04-21 — Use SwiftData for Saved Devices and Keychain References in the Phase 1 App Shell

### Context

The brief calls for known-device persistence in SwiftData and credential storage in Keychain, with device records referring to secrets indirectly rather than storing them in plain text.

### Decision

Implement the first app shell around a SwiftData `StoredColorBoxDevice` model and a Keychain credential store keyed by an opaque reference string.

### Consequences

- Saved ColorBox devices survive relaunches without storing passwords in the SwiftData store.
- The app can re-register devices into `DeviceManager` on launch using the same stable device UUIDs.
- Later persistence work can extend the same durability pattern to presets, snapshots, and other Phase 4 state.

## 2026-04-21 — Publish the Mock Server Over Bonjour With Provisional ColorBox-Oriented TXT Keys

### Context

The brief requires `MockColorBox` to advertise itself as `_http._tcp` so discovery work can proceed without hardware. The exact TXT record keys used by a real ColorBox are still unknown because the live device API and metadata remain unreachable from this Mac.

### Decision

Publish `MockColorBox` over Bonjour with a configurable service name and a lightweight TXT record containing provisional `vendor`, `product`, `path`, and `serial` keys that identify it as a ColorBox-like endpoint.

### Consequences

- TrackGrade discovery work can proceed against a locally advertised development target.
- The mock is locally discoverable today, but its TXT record schema may need to change once the real device advertisement is captured.
- Discovery filtering logic should continue to tolerate service-name fallback until the real TXT keys are verified.

## 2026-04-21 — Use The Live ColorBox `/v2` OpenAPI Contract As The New Integration Baseline

### Context

The real ColorBox at `172.29.14.51` became reachable over HTTP and exposed a Swagger UI at `/api/index.html` backed by `/api/openapi.yaml`. The live contract differs materially from the provisional mock and handwritten wrapper.

### Decision

Adopt the fetched live OpenAPI contract as the new source of truth for ColorBox integration, and treat the earlier `/system/info`, `/pipeline/state`, `/presets/*`, and `/preview/frame` routes as temporary scaffolding to be replaced.

### Consequences

- `Docs/openapi-colorbox.json` and `Docs/openapi-colorbox.yaml` are now the authoritative device contract snapshots in the repo.
- The provisional wrapper and mock will need a compatibility pass to match the real `/v2` endpoint surface.
- Any Phase 1 work built on the old guessed routes must be revalidated before it can count as true hardware parity.

## 2026-04-21 — TrackGrade Must Support ColorBox API-Key Auth, Not Just Username/Password

### Context

The live OpenAPI document declares an `app_id` security scheme carried in the `X-API-KEY` header. This conflicts with the earlier assumption that device auth would be handled by optional admin password and HTTP Basic Auth.

### Decision

Treat API-key support as the required auth model for real ColorBox write operations until the live hardware proves otherwise.

### Consequences

- The app’s current Keychain model and credential UI need to evolve beyond username/password fields.
- Mutating calls should not be switched to the generated hardware client until a real API-key flow is defined.
- `Docs/OPEN-QUESTIONS.md` must track the missing API-key input from the user.

## 2026-04-21 — Use The Generated `/v2` Client For Connect-Time Reads And Verified Mutations First

### Context

The live ColorBox spec is now committed and the generated client compiles. The real hardware clearly exposes `/v2/buildInfo`, `/v2/system/config`, `/v2/system/status`, `/v2/routing`, `/v2/pipelineStages`, `/v2/systemPresetLibrary`, and `/v2/preview`, but preset mutations and false color still lack a verified mapping.

### Decision

Move TrackGrade’s connect-time reads, preview fetch, preset listing, pipeline-node configuration, and bypass mutation onto the generated `/v2` client now, while leaving false color and preset save / recall / delete on the older provisional compatibility path until their live write semantics are confirmed.

### Consequences

- Real hardware connections now validate against the committed spec instead of the earlier guessed read routes.
- `MockColorBox` must serve matching `/v2` responses so integration tests continue to exercise the same contract shape.
- A later Phase 1 follow-up still needs to eliminate the remaining provisional mutation routes.

## 2026-04-21 — Treat The Reference ColorBox As Currently Unauthenticated While Preserving Future Auth Support

### Context

`GET /v2/system/config` on the reference hardware at `172.29.14.51` currently reports `authenticationEnable: false`, even though the spec declares an API-key security scheme.

### Decision

Treat credentials as optional for the current reference device, but preserve transport-layer support for both Basic auth and `X-API-KEY` headers so TrackGrade can target authenticated hardware later without reworking the client foundation again.

### Consequences

- Phase 1 hardware validation is no longer blocked on obtaining an API key from the current ColorBox.
- The app UI can defer API-key entry for a short time, but it remains required before TrackGrade can claim parity with authenticated devices.
- Open questions now focus more on preset and false-color mapping than on immediate credential acquisition.

## 2026-04-21 — Model Device-Native Presets Through `/v2/libraryControl`

### Context

Direct probing on the live ColorBox at `172.29.14.51` confirmed that preset mutations are not separate `/presets/*` routes on firmware `3.0.0.24`. Instead, the box uses `PUT /v2/libraryControl` actions against `library: "systemPreset"`.

### Decision

Implement device-native preset save / rename / recall / delete using:

- `StoreEntry` followed by `SetUserName` for save / overwrite.
- `RecallEntry` for preset recall.
- `DeleteEntry` for deletion.

### Consequences

- TrackGrade’s preset CRUD behavior now matches live hardware semantics instead of the earlier guessed provisional routes.
- `MockColorBox` must preserve the same `libraryControl` action flow so integration tests cover the real contract shape.
- False color is now the only unresolved Phase 1 control-path mismatch from the original guessed routes.

## 2026-04-21 — Defer Authentication UX Work For The Reference ColorBox

### Context

The reference ColorBox reports `authenticationEnable: false`, and the user confirmed that authentication will remain disabled for the foreseeable future.

### Decision

Keep the transport-layer credential support already in place, but remove authentication UX work from the current critical path.

### Consequences

- Phase 1 no longer depends on API-key entry or credential-management expansion for the reference hardware.
- The app can continue to preserve optional auth support for future hardware without spending immediate implementation time on it.
- Open questions should no longer block on authentication.

## 2026-04-21 — Treat False Color As Unsupported On ColorBox Firmware 3.0.0.24

### Context

The live `/v2` OpenAPI contract does not expose a false-color endpoint, and a follow-up pass over the device’s shipped web UI bundles also failed to reveal any hidden route or action related to false color.

### Decision

Treat false color as unsupported on firmware `3.0.0.24` for now, with TrackGrade surfacing a clear unsupported message instead of pretending the control is available.

### Consequences

- False color is no longer a blocker for current hardware integration work.
- Future work can revisit false color only if a newer firmware or vendor reference exposes a stable API path.
- The remaining Phase 1 hardware work can focus on LUT upload and other verified `/v2` capabilities.

## 2026-04-21 — Disable False Color UI When Firmware Or Runtime Behavior Marks It Unsupported

### Context

The reference ColorBox firmware `3.0.0.24` does not expose a false-color API path, and treating that as a generic transport failure makes the app look disconnected when the real issue is feature availability.

### Decision

TrackGrade should infer false-color availability from known unsupported firmware, mark the capability unavailable when a live toggle call returns the explicit unsupported-feature error, and disable the UI control instead of continuing to present a dead toggle.

### Consequences

- The grade screen now reflects capability state instead of inviting a control path that cannot succeed on the reference hardware.
- Unsupported false color no longer drives reconnect behavior or degraded connection state.
- Mock-backed integration tests now cover the unsupported-feature path directly.

## 2026-04-21 — Add An Offline UI Fixture Mode For Phase 2 Verification

### Context

Phase 2 needs app-level verification for the custom control surface, but the ColorBox will not always be reachable from the development machine and the Xcode project previously only had a placeholder UI-test file with no runnable UI-test target.

### Decision

Add a real `TrackGradeUITests` target and a `-ui-test-fixture` launch mode that boots the app with an in-memory SwiftData store plus a seeded fixture ColorBox snapshot whose preset and toggle state mutate locally.

### Consequences

- `xcodebuild test` can now verify key app flows without live hardware access.
- Fixture-backed tests can cover launch, bypass, settings, and preset save behavior deterministically.
- True simultaneous multi-touch and final sensitivity tuning still require manual validation on actual iPad hardware.

## 2026-04-21 — Treat Live `/v2/upload` Behavior As Unverified On Firmware 3.0.0.24

### Context

The committed OpenAPI spec and the shipped device web UI both point library imports at `POST /v2/upload`, but direct probes with valid `.cube` files returned `200` without creating visible entries in `GET /v2/3dLutLibrary` on the reference ColorBox.

### Decision

Do not implement TrackGrade’s live LUT import/write path on assumptions alone. Record the current `/v2/upload` behavior as unresolved until the library materialization semantics are verified against hardware or vendor guidance.

### Consequences

- LUT import is now the main remaining hardware integration uncertainty for the current phase.
- Further work should favor explicit probing and documentation over speculative implementation.
- The mock may continue to support provisional upload storage for testing, but the app should not claim live parity yet.

## 2026-04-21 — Defer Live LUT Import From The Current MVP

### Context

The reference firmware still has unresolved `/v2/upload` library materialization behavior, and the user explicitly said LUT import is not a deal breaker for this version.

### Decision

Do not treat live LUT import as an MVP requirement for the current release target. Prioritize direct control of the dynamic 3D LUT stage and saturation first, then preset save, then bypass, and leave LUT import for a later version.

### Consequences

- The current implementation path can focus on hardware-backed grade controls that already map cleanly to `/v2/pipelineStages`.
- The unresolved `/v2/upload` behavior remains documented, but it no longer blocks MVP progress.
- Future versions can revisit library import once hardware behavior is verified or vendor guidance is available.

## 2026-04-21 — Drive The Current MVP Grade Controls Directly Through `/v2/pipelineStages`

### Context

The reference ColorBox firmware cleanly exposes `lut3d_1.colorCorrector` and `lut3d_1.procAmp.sat` through `GET/PUT /v2/pipelineStages`, and the user elevated direct dynamic 3D LUT control plus saturation to the top MVP priority.

### Decision

Implement the current MVP grade path by reading and writing the dynamic stage fields directly on `/v2/pipelineStages`, rather than waiting for LUT bake/upload work.

### Consequences

- TrackGrade can already deliver live Lift / Gamma / Gain and saturation control on the reference hardware.
- The grade UI and device state model should treat `pipelineStages` as the source of truth for the current MVP look state.
- Preset behavior now has to be evaluated against this direct stage-control path, not against a future uploaded-LUT workflow.

## 2026-04-21 — Persist The Dynamic LUT Before Saving A Device-Native Preset

### Context

Direct grading through `PUT /v2/pipelineStages` successfully updates `lut3d_1.colorCorrector` and `procAmp.sat` on the reference ColorBox, but `StoreEntry` plus `SetUserName` alone did not preserve those runtime dynamic-grade values when the preset was recalled later on firmware `3.0.0.24`.

### Decision

When TrackGrade saves a ColorBox-resident preset for the dynamic grading workflow, it must first call `POST /v2/saveDynamicLutRequest`, then `StoreEntry`, then `SetUserName`.

### Consequences

- TrackGrade can satisfy the MVP requirement that presets live on the ColorBox instead of the iPad.
- The mock server and integration tests must preserve the same sequence so package tests match the live device contract.
- Preset save is now tied to the device's persisted dynamic-LUT snapshot step and should not be simplified back to `StoreEntry` alone.

## 2026-04-21 — Keep Presets Device-Native Because The iPad Is Ephemeral

### Context

The user clarified that preset data must live on the ColorBox itself and that the iPad should be considered ephemeral.

### Decision

Do not introduce TrackGrade-local preset storage as an MVP fallback. Device-native ColorBox presets are the required behavior.

### Consequences

- Any preset workflow that does not round-trip through the ColorBox is out of scope for the MVP.
- Device-side preset save and recall correctness remain more important than iPad-side snapshot convenience.
- Open questions should not present local-only presets as an acceptable substitute.

## 2026-04-21 — Map Phase 2 Trackball Controls Directly Onto The Current `pipelineStages` Grade Values

### Context

Phase 2 needs the touch-native trackball, ring, and saturation controls now, but Phase 3 LUT baking and upload are still future work. The current MVP grading path already writes live Lift / Gamma / Gain / Saturation values directly through `PUT /v2/pipelineStages`.

### Decision

Represent each Phase 2 trackball as a `ball + ring` control state, and map that state directly to the existing ColorBox grade vectors used by `lut3d_1.colorCorrector` and `procAmp.sat`.

### Consequences

- The custom controls can ship on top of the already-verified hardware grading path instead of waiting for Phase 3 LUT baking.
- TrackGrade now needs deterministic round-trip helpers between touch-state and device-state so preset recall and refresh keep the control surface visually aligned.
- A later Phase 3 LUT-bake path may replace the transport, but it should preserve the same higher-level touch control model if possible.

## 2026-04-21 — Persist Phase 2 Sensitivity And Feedback Settings With AppStorage

### Context

Phase 2 needs user-adjustable sensitivity values and haptics preferences immediately, but the broader long-term settings model from the brief is still larger than the current implementation scope.

### Decision

Use `@AppStorage`-backed settings keys for the initial Phase 2 control-surface tuning values and haptics toggle.

### Consequences

- Sensitivity and feedback settings persist across launches without adding new SwiftData schema work mid-phase.
- The grade surface and settings sheet can share one lightweight persistence path today.
- A later, more comprehensive settings architecture may absorb these keys, but it should preserve migration from the current stored values.

## 2026-04-21 — Reshape The Grade Screen Into A Static Landscape Control Surface

### Context

The first live UI review showed that the current vertically scrolling grade screen is not viable for the intended iPad control-surface workflow. The layout needs to stay fixed, keep grading controls visible at once, and compress telemetry so the operator is not scrolling during a show.

### Decision

For the next Phase 2 UI pass:

- Remove vertical scrolling from the main grading interface.
- Compress telemetry into smaller, denser regions.
- Use a compact top-center LGG/S state display and place secondary telemetry to the sides.
- Allow bypass, presets, and related secondary controls to live in a drawer if needed.
- Move saturation above the trackballs.
- Keep reset controls for Lift / Gamma / Gain / Saturation visibly present in the main layout.

### Consequences

- The current stacked-card layout is a temporary implementation and should be treated as transitional.
- The next UI refactor should optimize for a fixed live-operation surface rather than for inspector-style content flow.
- Secondary controls may become less immediately exposed, but the core grading gestures and their state readout should become faster to operate in show conditions.

## 2026-04-21 — Keep Bypass In The Main Bar And Move Presets / Secondary Actions Into A Drawer

### Context

The static-layout refactor needed to preserve immediate access to the MVP-critical bypass toggle while still reclaiming enough room for the grading surface, visible reset controls, and compact telemetry.

### Decision

- Keep the bypass toggle in the always-visible main control bar.
- Move presets, false color, refresh / configure actions, and similar secondary operations into a slide-over drawer.
- Keep device and pipeline telemetry as compact side panels around the centered LGG / Saturation state display.

### Consequences

- The main grading surface stays fixed and uncluttered while still exposing the highest-priority show control.
- Offline UI tests need to open the drawer before preset assertions instead of assuming all secondary actions remain visible at launch.
- Real-hardware validation should focus on whether the drawer still feels fast enough during operation or whether any secondary controls need promotion back to the main surface.

## 2026-04-21 — Use Fixed Drawer Panels For Workflow, Presets, And Device Actions

### Context

Once snapshots, scratch slots, presets, and device actions were all added to the secondary drawer, the drawer itself became too tall for a fixed-height live control surface. Reintroducing vertical scrolling there would have undermined the static-layout direction captured during the live UI review.

### Decision

Split the secondary drawer into three fixed panels selected by a segmented control:

- `Workflow` for undo / redo, snapshots, and A/B scratch slots.
- `Presets` for ColorBox-resident preset save / recall / delete.
- `Device` for refresh / configure / connect actions and optional controls such as false color.

### Consequences

- The main grading surface and the secondary drawer can both stay fixed-height without hiding controls below the fold.
- Offline UI tests now have an explicit, deterministic navigation path to each secondary function.
- Real-hardware validation should confirm that segmented drawer switching still feels quick enough during operation.

## 2026-04-21 — Seed Offline UI Fixtures Through SwiftData Instead Of Memory-Only Snapshot State

### Context

Phase 4 snapshot save writes through SwiftData, but the original offline fixture mode only populated snapshot data in memory. That mismatch meant fixture-based snapshot tests were not exercising the same persistence path as the real app.

### Decision

When the app launches with `-ui-test-fixture`, seed the fixture devices and snapshots into the SwiftData model container before the UI loads, then read them back through the normal fetch path.

### Consequences

- Snapshot save / recall tests now verify the same persistence flow used by the live app instead of a fixture-only shortcut.
- Fixture launches become more durable across test cases because the app resets and reseeds its local store explicitly.
- Future offline workflow features can rely on the same fixture persistence contract without adding more test-only branches.

## 2026-04-21 — Expose The Current Grade Summary Through The Main Control-Surface Accessibility Contract

### Context

Row-level numeric state elements proved unstable as UI-test hooks because SwiftUI flattened their accessibility shape differently across runs. The grading surface itself already had a stable accessibility identifier.

### Decision

Publish the current LGG / Saturation summary as the accessibility value of the main `dynamic-grade-card` element, and use that as the automation contract for snapshot recall assertions.

### Consequences

- Snapshot recall tests can verify real grade-state changes without depending on fragile row-level accessibility behavior.
- The app gains a more coherent high-level accessibility summary of the current grade state.
- Future UI test work should prefer stable screen-level accessibility contracts when validating composite grading state.
