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
