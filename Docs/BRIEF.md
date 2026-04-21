📋 Project Brief: TrackGrade
iPad Control Surface for AJA ColorBox — Implementation Specification for CODEX
Version: 1.0
Date: 2026-04-21
Target Implementer: CODEX (GPT-5.4 via CODEX Mac app harness)
Repository: TBD (GitHub, open source, license TBD — suggest Apache-2.0 or MIT)

0. Executive Summary
TrackGrade is a native iPadOS 18+ application that provides a touch-based trackball control surface for live color grading via AJA ColorBox hardware. It is purpose-built for IMAG (image magnification) feeds to large LED screens at corporate live events — short-duration, small-adjustment color correction during live shows.

The app communicates directly with one or more ColorBox units on the same LAN subnet over the ColorBox REST API. No intermediary server. No cloud. No external dependencies at runtime.

Core interaction model: Three virtual trackballs (Lift / Gamma / Gain), each with an outer luminance ring, plus a saturation roller. User manipulations are converted to ASC-CDL values, baked into a 33³ 3D LUT, and uploaded to the ColorBox's Dynamic 3D LUT node in the AJA Color pipeline.

Key differentiators vs. Livegrade / Live Looks: dramatically simpler, purpose-built for live event IMAG, no macOS host required, runs entirely on iPad.

1. Operating Environment
Item	Value
Target OS	iPadOS 18.0+
Devices	Any iPad capable of running iPadOS 18
Orientation	Landscape only (locked)
Network	Same LAN/subnet as ColorBox(es); IPv4; mDNS/Bonjour enabled
Hardware target	AJA ColorBox, firmware ≥ current production release (document version tested)
Pipeline target	AJA Color Pipeline only
Offline mode	Mock ColorBox server (see §10)
2. Technology Stack
Layer	Choice
Language	Swift 6 (strict concurrency)
UI	SwiftUI + Observable macro
Async	Swift Concurrency (async/await, AsyncSequence, Task)
Graphics	SwiftUI Canvas for trackballs/ring/roller rendering
Gestures	Custom UIGestureRecognizer subclasses bridged to SwiftUI via UIViewRepresentable (for true multi-touch independence)
Networking	URLSession + Codable; no third-party HTTP libs
API client	Generated from ColorBox's OpenAPI spec using swift-openapi-generator
Persistence	SwiftData for presets, snapshots, device credentials (credentials stored in Keychain, referenced by ID from SwiftData)
Credential storage	iOS Keychain (kSecClassGenericPassword)
Discovery	NWBrowser (Bonjour _http._tcp filtered by AJA TXT records)
Haptics	CoreHaptics
Testing	XCTest (unit), XCUITest (UI snapshot), Swift Testing for integration
Mock server	Vapor-based Swift executable (separate SPM target)
Min deployment	iPadOS 18.0
Architecture pattern: MVVM with @Observable view models. One root AppState actor holds device connections. Feature-scoped view models subscribe to device state streams.

Project layout (SPM + Xcode):


TrackGrade/
├── App/                          # SwiftUI App entry, root views
├── Features/
│   ├── Connect/                  # Discovery, pairing, device picker
│   ├── Grade/                    # Trackball/ring/roller UI + view models
│   ├── Presets/                  # Preset + snapshot management
│   ├── Library/                  # LUT/image/overlay management
│   ├── Settings/                 # Config (sensitivity, colorspace, etc.)
│   └── Preview/                  # Frame preview thumbnail
├── Core/
│   ├── ColorMath/                # CDL, LUT baking, color space transforms
│   ├── ColorBoxAPI/              # Generated OpenAPI client + wrappers
│   ├── DeviceManager/            # Connection pool, queue, retry
│   ├── Persistence/              # SwiftData models
│   └── Haptics/                  # Haptic patterns
├── UIKit/                        # Multi-touch gesture recognizers
├── MockServer/                   # Separate SPM target — mock ColorBox
├── Tests/
│   ├── UnitTests/                # Color math, LUT bake, CDL
│   ├── IntegrationTests/         # Against mock server
│   └── UITests/                  # Snapshot + interaction
└── Docs/
    ├── ARCHITECTURE.md
    ├── API-MAPPING.md
    ├── USER-GUIDE.md
    └── COLOR-SCIENCE.md
3. ColorBox Integration
3.1 Pipeline Configuration (set once on connect)
The app configures the AJA Color Pipeline with:

Node 4 (3D LUT): set to "Dynamic" mode — this is the LGG target.
Nodes 1, 2, 3, 5, 6, 7: pass-through (identity), unless user loads an input or output transform (v1 scope: always identity).
On first connect, if pipeline is not in this configuration, prompt user: "Configure ColorBox for TrackGrade? This will set the 3D LUT node to Dynamic mode."

3.2 LUT Upload Strategy
Resolution: 33³ (standard, matches ColorBox internal).
Format: .cube (Iridas/Adobe), text.
Upload path: ColorBox REST endpoint for dynamic LUT replacement (verify exact route from OpenAPI spec at /api — generate client and map).
Rate limiting: Coalesce updates. The DeviceManager maintains a single in-flight upload per device; if a new LUT is computed while one is uploading, the pending one replaces it (last-write-wins). This naturally throttles to the device's ingest rate without dropping user intent.
Touch-up commit: On finger lift, always send one final upload to guarantee the on-device LUT matches the UI state.
Idempotency: Each upload carries a monotonic sequence ID in a request header for debugging; ColorBox ignores it.
3.3 API Surface Used
From the ColorBox OpenAPI spec (generate client; verify exact paths):

Capability	Endpoint category
System info / health	GET /system/*
Pipeline selection & state	GET/PATCH /pipeline/*
Node configuration (AJA Color nodes 1–7)	GET/PATCH /pipeline/aja/nodes/*
Dynamic 3D LUT upload	PUT /pipeline/aja/nodes/3dlut/dynamic (verify)
Pipeline bypass	PATCH /pipeline/bypass
False color	PATCH /pipeline/false-color
Presets (list / save / recall / delete / startup)	GET/POST/DELETE /presets/*
Library (1D/3D/matrix/image/overlay/AMF slots)	GET/POST/DELETE /library/*
Frame preview	GET /preview/frame (jpeg/png)
I/O format info	GET /io/*
Alarms / temperature	GET /alarms
License / firmware	GET /system/license, GET /system/firmware
Auth	Basic or session, per device config
Task for CODEX: on Phase 1 kickoff, fetch the live OpenAPI JSON from a reference ColorBox (user will provide IP during development) and commit it to Docs/openapi-colorbox.json. Use swift-openapi-generator to produce the typed client. Write API-MAPPING.md cross-referencing every endpoint used.

3.4 Authentication
On device add, prompt for optional admin password.
Store password in Keychain keyed by device UUID.
Use HTTP Basic auth (confirm scheme from spec).
If a 401 is returned mid-session, surface a re-auth sheet without losing local state.
3.5 Device Discovery
On app launch and on-demand, NWBrowser scans for _http._tcp.local. services.
Filter by TXT record (AJA-specific key — verify; fallback: GET /system/info and match product string ColorBox).
Show found devices + "Add manually by IP" option.
Persist known devices (name, IP, UUID, credentials ref) in SwiftData.
3.6 Connection Resilience
Each device has a ConnectionState: .disconnected | .connecting | .connected | .degraded | .error(Error).
On network drop:
Enter .degraded state.
Continue accepting user input; latest LUT is queued.
Retry with exponential backoff (1s, 2s, 4s, 8s, cap 30s).
Show non-modal banner: "Connection lost to [device]. Retrying…" with manual retry button.
On reconnect, immediately upload latest queued LUT + resync state.
If user dismisses the banner, suppress for 60s then re-show if still degraded.
3.7 Multi-Device (Ganging)
Up to 10 devices concurrently.
Gang set UI: multi-select toggle in device picker.
When a gang is active, every LUT upload / bypass / false-color / preset recall broadcasts to all ganged devices in parallel (each device has its own upload queue; no cross-device blocking).
State display reflects the "focus" device (one device designated primary); an indicator shows if ganged devices have drifted out of sync (e.g., user manually changed one via its web UI).
Optional: ungang to make a per-device offset adjustment, then re-gang.
4. Color Math Specification
4.1 ASC-CDL Model
Per channel (R, G, B):
out=(in×Slope+Offset) 
1/Power
 

Then saturation applied in the working color space:
luma=w 
R
​
 ⋅R+w 
G
​
 ⋅G+w 
B
​
 ⋅B
out 
C
​
 =luma+Sat×(C−luma),C∈{R,G,B}

Rec.709 luma coefficients: w 
R
​
 =0.2126, w 
G
​
 =0.7152, w 
B
​
 =0.0722.

4.2 Mapping Trackballs → CDL Parameters
Three trackballs feed three separate CDL operations composed in series (Lift → Gamma → Gain), baked into a single 33³ LUT.

Control	CDL mapping
Lift ball (2D offset within unit circle)	Chromatic offset: small additive bias in RGB. (x, y) → hue vector in Rec.709 primaries space, magnitude ∈ [0, 0.2]
Lift ring	Luminance lift: adds a constant to all RGB, range ±0.2
Gamma ball	Chromatic mid-tone bias: modulates Power per channel around 1.0
Gamma ring	Overall power: Power∈[0.2,5.0], default 1.0, exponential curve on the ring
Gain ball	Chromatic slope bias: modulates Slope per channel around 1.0
Gain ring	Overall slope: Slope∈[0.0,4.0], default 1.0
Sat roller	Sat∈[0.0,2.0], default 1.0
Exact chromatic-ball-to-per-channel formula (example for Lift; analogous for Gamma/Gain):

Given ball offset (x,y)∈[−1,1] 
2
  constrained to unit disk, with magnitude m= 
x 
2
 +y 
2
 
​
  and angle θ=atan2(y,x):

Map θ to an RGB tint vector using hue-wheel convention (0° = red, 120° = green, 240° = blue):
ΔR=m⋅k⋅cos(θ)
ΔG=m⋅k⋅cos(θ−120°)
ΔB=m⋅k⋅cos(θ−240°)
k = per-control scale factor (Lift: 0.1; Gamma: 0.2 in power space; Gain: 0.2 in slope space — all tunable in settings).
Reference implementation: Core/ColorMath/CDL.swift. Must ship with unit tests validating identity (all defaults → identity LUT within 1e-6), Slope/Offset/Power/Sat against published ASC-CDL test vectors.

4.3 Working Color Space & Transfer Function
v1 supports: Rec.709 SDR (gamma 2.4), Rec.709 HLG.
CDL math is applied in the linear domain. Pipeline:
Input LUT samples (∈ [0, 1] code values) → linearize using selected transfer function.
Apply CDL (Slope/Offset/Power) in linear.
Apply saturation using Rec.709 luma weights in linear.
Re-encode using selected transfer function.
Clamp to [0, 1] and write to .cube.
Transfer functions as first-class types in Core/ColorMath/TransferFunction.swift; protocol-based for future expansion (S-Log3, LogC, PQ, etc.).
Settings UI exposes working colorspace selection per device.
4.4 LUT Baking
LUTBaker.bake(cdl: CDLValues, sat: Float, transferFunction: TF, size: Int = 33) -> CubeLUT
Output format: Iridas .cube text, TITLE "TrackGrade <timestamp>", domain 0–1.
Performance target: bake + serialize < 16ms on iPad Pro M-series (profile and document actual). Use Accelerate.vDSP for vectorized ops.
Bake happens off main actor on a dedicated Task.
4.5 Saturation Bounds
Hard clamp Sat∈[0.0,2.0].
Verify ColorBox accepts resulting LUT; document any observed internal clamping.
5. User Interface Specification
5.1 Layout (landscape, any iPadOS 18 iPad)

┌──────────────────────────────────────────────────────────────────────────┐
│ [Devices ▼ "Stage-L + 2"]  [Bypass] [False Color] [Before/After]  [⚙︎]  │ 44pt top bar
├──────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│                   ┌──── STATE DISPLAY (focal) ─────┐                     │
│                   │ Lift  R+0.02 G-0.01 B+0.03  L+5│ Top-center,         │
│                   │ Gamma R 1.02 G 1.00 B 0.98  γ1.1│ ~180pt tall,       │
│                   │ Gain  R 1.01 G 0.99 B 1.02  S1.0│ monospaced,        │
│                   │ Sat 1.00   [●preview thumb]    │ live-updating.     │
│                   └────────────────────────────────┘                     │
│                                                                          │
│   ┌────────────┐        ┌────────────┐        ┌────────────┐             │
│   │   LIFT     │        │   GAMMA    │        │   GAIN     │             │
│   │  ┌──────┐  │        │  ┌──────┐  │        │  ┌──────┐  │             │
│   │  │ ring │  │        │  │ ring │  │        │  │ ring │  │             │
│   │  │ ●ball│  │        │  │ ●ball│  │        │  │ ●ball│  │             │
│   │  └──────┘  │        │  └──────┘  │        │  └──────┘  │             │
│   │ [↺ball][↺r]│        │ [↺ball][↺r]│        │ [↺ball][↺r]│             │
│   └────────────┘        └────────────┘        └────────────┘             │
│                                                                          │
│   ┌──────────────────────  SATURATION  ───────────────────────┐          │
│   │ 0.00 [═══════════════●════════════════] 2.00   Value: 1.00│          │
│   └──────────────────────────────────────────────────────────┘          │
│                                                                          │
│ [Reset All] [Undo] [Redo]    Presets: [1][2][3][4][5][6][7][8][9][10]   │
│                                          Snapshots [+][A][B]…  [Library]│
└──────────────────────────────────────────────────────────────────────────┘
State display is top-center and always visible. Shows live numeric readout for all CDL params. Tap any value to edit with numeric keyboard. Tap the preview thumb to toggle input/output; long-press to refresh.
Before/After toggle: flips between graded and ungraded output (invokes pipeline bypass) with a large clear button + haptic confirmation.
Bypass button: same as Before/After but persists state for the ColorBox's own pipeline bypass. (These are two distinct controls.)
Reset All: double-tap required.
5.2 Trackball Control Specification
Each trackball cluster comprises:

Outer ring — 1D radial control, rotates around center. Drag tangentially to adjust.
Inner ball — 2D control within the ring. Drag to offset from center.
Reset ball button (require double-tap).
Reset ring button (require double-tap).
Behavior:

Relative touch mode: on touch-down, record anchor point + current value. On drag, newValue = anchorValue + (currentTouch - anchorTouch) × sensitivity. On touch-up, hold value (no spring-back). Next touch-down resumes from current value.
Sensitivity: per-control multiplier in Settings (sliders labeled Lift/Gamma/Gain Ball, Lift/Gamma/Gain Ring, Sat; range 0.25× to 4.0×, default 1.0×).
Multi-touch: independent simultaneous control of multiple balls/rings/rollers. Implementation uses a custom UIGestureRecognizer per control, all set to recognize simultaneously, bridged to SwiftUI. Do not use SwiftUI's DragGesture alone — its gesture arbitration will serialize touches.
Ball constraint: ball position clamped to unit disk (radius 1). If user drags outside, anchor slides along the circle edge following the finger angle, so releasing + re-dragging inward smoothly reduces magnitude.
Apple Pencil: ignore (treat as finger for now; filter with UITouch.type → drop .pencil).
Haptics:
Light UIImpactFeedbackGenerator(.light) tick when ball crosses center (radius < 0.02 from origin).
Medium impact on any button press.
Success notification on preset recall / reset.
CoreHaptics for custom "detent" feel on ring when crossing zero.
Rendering:

SwiftUI Canvas with @Observable view model driving updates.
Ring: drawn as two arcs (base + value indicator).
Ball: filled circle with drop shadow; the ball's fill color reflects the current RGB tint for visual feedback (a Lift ball pushed toward red appears reddish).
60 Hz minimum; profile on baseline iPad (e.g., iPad 10th gen).
5.3 Saturation Roller
Horizontal slider, full-width, ~80pt tall.
Drag thumb or tap anywhere on track.
Double-tap to reset to 1.0.
Numeric readout at right; tap to edit.
Haptic detent at 1.0.
5.4 Settings Panel (⚙︎)
Per-device:
Working color space (Rec.709 SDR / Rec.709 HLG)
Admin password (Keychain, masked)
Friendly name
Gang membership
Global:
Sensitivity sliders (7 controls)
Haptics on/off
Preview auto-refresh interval (Off / 1s / 5s / 10s)
LUT resolution (33 fixed in v1, but exposed as read-only for future)
Reset-all confirmation required (on/off)
Export diagnostic log
About / licenses / open source notices
5.5 Presets & Snapshots
Presets (10, device-native): thumbnails + names; tap to recall with confirmation sheet; long-press to rename or overwrite. Sync bidirectionally with ColorBox.
Snapshots (unlimited, iPad-local): stored in SwiftData. Each snapshot captures full CDL + sat state + thumbnail (pulled from preview frame). Use cases: A/B compare, show cues.
A/B compare: two dedicated scratch slots with big [A] / [B] buttons. Tap to flip; double-tap to overwrite with current state.
5.6 Undo / Redo
50-step global history of grade state changes (push on touch-up, not during drag).
Undo/redo buttons in bottom toolbar.
Keyboard shortcut ⌘Z / ⇧⌘Z (external keyboard).
Not persisted across app launches.
5.7 Frame Preview
Small thumbnail (~120×68pt) embedded in the state display area.
Manual refresh button + auto-refresh per settings interval.
Tap to toggle input vs. output (pre/post pipeline).
Tap-and-hold to enlarge to half-screen overlay.
5.8 Library Management
Full-screen modal reachable from bottom toolbar.
Lists all 16 slots per asset type (1D LUT, 3D LUT, 3x3 matrix, image, overlay, AMF).
For v1: read-only browse + delete. Import from Files app is a stretch goal, noted in ARCHITECTURE.md backlog. ✳️ Confirm with user if import should be in v1.
5.9 Accessibility
Dynamic Type supported for all non-canvas text.
VoiceOver labels for buttons; trackballs announce current RGB values on focus.
Sufficient contrast (WCAG AA).
"Reduce Motion" respected (disable ring/ball entry animations).
6. State Management
6.1 Core State Types

@Observable final class GradeState {
    var lift:  CDLControlState  // ball (x,y) + ring value
    var gamma: CDLControlState
    var gain:  CDLControlState
    var saturation: Float
    
    func toCDL() -> CDLValues { … }
    func bakeLUT(tf: TransferFunction, size: Int) -> CubeLUT { … }
}

struct CDLControlState: Equatable {
    var ball: SIMD2<Float>   // unit disk, [-1, 1] constrained
    var ring: Float          // [-1, 1] or [0, ∞) depending on control
}

@Observable final class DeviceState {
    let id: UUID
    var name: String
    var address: String
    var connection: ConnectionState
    var pipelineInfo: PipelineInfo?
    var presets: [PresetSummary]
    var lastPreviewFrame: UIImage?
    var gang: Bool
}

@Observable final class AppState {
    var devices: [DeviceState]
    var focusDevice: UUID?
    var grade: GradeState
    var undoStack: [GradeState]
    var redoStack: [GradeState]
    var snapshots: [Snapshot]   // SwiftData-backed
    var settings: Settings
}
6.2 Update Flow
User touches trackball → gesture recognizer mutates GradeState (60 Hz).
GradeState change triggers debounced (8 ms) bake task.
Baked LUT queued in DeviceManager.uploadQueue[deviceID]; if idle, uploaded immediately; if busy, replaces pending.
On touch-up, final bake + upload pushed with .committed flag; this entry pushed to undo stack.
UI state display reflects GradeState directly — no round-trip to device required for responsiveness.
7. Mock ColorBox Server
Required. Enables development without hardware.

Separate SPM executable target: MockColorBox.
Vapor-based HTTP server.
Serves the same OpenAPI spec as a real ColorBox (reuse committed openapi-colorbox.json).
Accepts LUT uploads; stores in-memory; exposes via GET for inspection.
Serves a static test image through /preview/frame (PNG of a color chart).
Advertises itself via Bonjour as _http._tcp with AJA-style TXT records.
Configurable latency injection (for testing upload coalescing).
Runs on macOS; documented in Docs/MOCK-SERVER.md.
8. Testing Strategy
8.1 Unit Tests (Tests/UnitTests/)
CDLMathTests: identity, known vectors, edge cases (Slope=0, Power→0, negative Offset).
TransferFunctionTests: round-trip error < 1e-5 for all supported TFs at 1024 sample points.
LUTBakerTests: identity bake round-trips; .cube parser/serializer symmetric; 33³ structure.
SaturationTests: Sat=0 → monochrome at correct luma; Sat=1 → identity.
Coverage target: 90% of Core/ColorMath/.
8.2 Integration Tests (Tests/IntegrationTests/)
Spin up MockColorBox in-process.
Test discovery, auth, pipeline config, LUT upload, preset CRUD, bypass, false color, preview fetch.
Test upload coalescing: hammer with 1000 updates, verify last one always reaches device.
Test connection drop + recovery (server pause/resume).
8.3 UI Tests (Tests/UITests/)
XCUITest snapshot tests at each phase milestone.
Interaction tests: verify multi-touch on two trackballs simultaneously (using XCUIElement.press multi-touch APIs).
Accessibility audit via XCUIApplication.performAccessibilityAudit().
8.4 Manual Test Plan
Include Docs/TEST-PLAN.md with checklist for manual hardware validation before each release.

9. Phased Delivery Plan
Each phase has hard acceptance criteria that must pass before proceeding.

Phase 0 — Scaffolding & Mock Server (est. 1 week)
 Xcode project + SPM packages created.
 Repo initialized, .gitignore, LICENSE, README stub.
 OpenAPI spec fetched and committed.
 swift-openapi-generator integrated; client compiles.
 MockColorBox serves spec + basic endpoints.
 CI pipeline (GitHub Actions) runs unit tests on PR.
 Acceptance: swift test passes; MockColorBox discoverable via Bonjour from a second Mac.
Phase 1 — Connectivity & State Plumbing (est. 1 week)
 Device discovery UI.
 Add/remove device manually by IP.
 Auth prompt + Keychain storage.
 Pipeline config (set node 4 to Dynamic).
 Bypass, false color toggles functional.
 Preset list/recall/save.
 Frame preview fetch + display.
 Connection resilience (drop + reconnect).
 Acceptance: app connects to mock server, all listed functions work; integration tests green.
Phase 2 — Custom Controls (est. 2 weeks)
 Trackball + ring component with multi-touch (all via UIGestureRecognizer bridge).
 Saturation roller.
 Reset buttons (double-tap).
 Sensitivity tuning in Settings.
 Haptics.
 Numeric state display, tap-to-edit.
 Acceptance: two fingers on two trackballs simultaneously produce independent updates; snapshot UI tests green.
Phase 3 — Color Math & LUT Upload (est. 1.5 weeks)
 CDL implementation + tests.
 Transfer function implementations.
 LUT baker.
 Wire trackballs → bake → upload queue.
 Verify identity round-trip end-to-end with mock.
 Acceptance: color math unit tests ≥ 90% coverage; mock receives correct LUTs; timing < 16ms bake.
Phase 4 — Presets, Snapshots, A/B, Undo (est. 1 week)
 SwiftData models for snapshots.
 A/B scratch slots with haptic flip.
 50-step undo/redo.
 Preset thumbnails.
 Acceptance: full grading workflow usable end-to-end.
Phase 5 — Multi-Device Gang (est. 0.5 week)
 Gang selection UI.
 Parallel broadcast with per-device queues.
 Drift indicator.
 Acceptance: 3 mock instances grade in sync.
Phase 6 — Polish, Docs, TestFlight (est. 1 week)
 Library browse UI.
 Accessibility pass.
 Complete ARCHITECTURE.md, USER-GUIDE.md, COLOR-SCIENCE.md, API-MAPPING.md.
 Icon + launch screen.
 TestFlight build + onboarding flow.
 Acceptance: TestFlight build installed and validated against real hardware.
Total: ~8 weeks for a single developer. CODEX should track phases in GitHub Issues/Projects.

10. Open Source Release Plan
License: Apache-2.0 (permissive + patent grant, good for corporate adoption). Final choice: user's call.
Repo hygiene: CONTRIBUTING.md, CODE_OF_CONDUCT.md, issue & PR templates, semantic versioning, tagged releases.
Attribution: ColorBox is AJA's trademark; include disclaimer in README that TrackGrade is not affiliated with or endorsed by AJA.
Third-party notices: Auto-generated from SPM dependencies, bundled in app + NOTICES.md.
11. Persistence & State Durability (CODEX-Specific)
Critical instruction to CODEX:

All project artifacts must be saved to durable local storage (the CODEX Mac app workspace directory). At the end of every working session, commit progress to the local Git repository. Do not rely on ephemeral context. If context is truncated, resume by reading the current state from disk.

Specifically:

Working directory: ~/Developer/TrackGrade/ (or user-chosen path).
Every code change committed to a local branch immediately after file save.
Docs/PROGRESS.md updated at the end of each session: current phase, completed items, open questions, next steps.
Decisions log in Docs/DECISIONS.md (ADR-style; one entry per nontrivial architectural choice).
No work exists only in chat context.
Before writing any code, CODEX should:

Read this brief in full.
Read Docs/PROGRESS.md (if present) to resume.
Read Docs/DECISIONS.md for prior constraints.
Summarize current state and proposed next actions to user for confirmation.
12. Deliverables Checklist
 Working TrackGrade iPad app (TestFlight-ready)
 MockColorBox Swift executable
 Full test suite (unit + integration + UI) passing in CI
 README.md (open-source-ready)
 ARCHITECTURE.md
 API-MAPPING.md
 COLOR-SCIENCE.md
 USER-GUIDE.md
 MOCK-SERVER.md
 PROGRESS.md (living)
 DECISIONS.md (living)
 TEST-PLAN.md
 CONTRIBUTING.md, CODE_OF_CONDUCT.md, LICENSE, NOTICES.md
 GitHub Actions CI config
 App icon, launch screen
 Tagged v0.1.0 release
13. Open Items Requiring User Input (flag these to CODEX)
Apple Developer Team ID + Bundle ID prefix (e.g., com.yourname.trackgrade).
Reference ColorBox IP address for OpenAPI fetch during Phase 0.
ColorBox firmware version to target.
License final decision (Apache-2.0 suggested).
Library import from Files app — v1 or v2?
GitHub repo name + visibility timeline (private during dev → public at v0.1.0?).
App icon design (placeholder OK for TestFlight).
Name confirmation: TrackGrade (or alternative).
14. Success Criteria
TrackGrade v1.0 is successful if:

A colorist can, during a live corporate event, make small CDL adjustments to IMAG feeds on an iPad with perceptually-immediate feedback.
Adjustments propagate to a real AJA ColorBox with less than 100 ms end-to-end latency from finger-up (target; measure and document actual).
The app gracefully survives network hiccups without losing grade state.
A new user can go from app install to first successful grade in under 5 minutes.
All tests pass; app passes App Store review; open source release is approved.