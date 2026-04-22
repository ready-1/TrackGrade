# Architecture

## Overview

TrackGrade is a native iPadOS 18+ SwiftUI app that talks directly to one or more AJA ColorBox units over the local network. The current implementation is optimized around the MVP path that is already working against real hardware:

- connect to a ColorBox over LAN
- configure the Dynamic 3D LUT node for TrackGrade
- drive Lift / Gamma / Gain plus saturation through `/v2/pipelineStages`
- save, recall, and delete device-native presets on the ColorBox
- broadcast core grade actions from the focused device to linked gang peers
- keep iPad-local snapshots, scratch A/B slots, and undo / redo for operator workflow

The app is split into an iPad app target plus a shared SwiftPM package:

- `TrackGrade.xcodeproj` contains the iPad app shell and UI tests
- `Package.swift` builds the shared `TrackGradeCore` sources and the `MockColorBox` executable

## High-Level Structure

### App

- `App/TrackGradeApp.swift`
  - creates the SwiftData container
  - switches to an in-memory store when `-ui-test-fixture` is present
- `App/ContentView.swift`
  - owns the root `NavigationSplitView`
  - hosts the connection banner, add-device sheet, auth sheet, and detail surface
- `App/TrackGradeAppModel.swift`
  - main app-facing state holder
  - coordinates persistence, discovery, device commands, snapshots, and offline fixture behavior

### Features

- `Features/Connect`
  - saved devices, discovery, manual add, auth updates, gang linking
- `Features/Grade`
  - fixed landscape grading surface
  - custom touch controls, telemetry, preview thumb, workflow drawer
- `Features/Presets`
  - device-native preset save / recall / delete UI
- `Features/Settings`
  - sensitivity tuning, haptics, reset behavior, about metadata
- `Features/Preview`
  - lightweight preview rendering helper
- `Features/Library`
  - slot-aware device library manager
  - groups live and fixture library entries into 1D LUT, 3D LUT, matrix, image, overlay, and AMF sections
  - supports import, replace, rename, and delete flows for supported device library kinds

### Core

- `Core/ColorBoxAPI`
  - generated OpenAPI client artifacts
  - handwritten wrapper that maps TrackGrade actions onto verified `/v2` routes
- `Core/DeviceManager`
  - actor-isolated connection pool
  - reconnect handling, per-device refresh, command execution
  - per-device dynamic LUT upload queue with last-write-wins coalescing
- `Core/ColorMath`
  - `CDLValues`, `GradeState`, `TransferFunction`, `CubeLUT`, and `LUTBaker`
  - converts control-surface state into CDL values, bakes `33^3` LUTs, and serializes `.cube` payloads
- `Core/Haptics`
  - central haptic helpers for button and control-surface feedback
- `Core/Persistence`
  - lightweight shared persistence value types used by tests and core-facing flows
  - authoritative app persistence remains SwiftData-backed in `App/`

### UIKit

- custom simultaneous-touch recognizer bridge used by the grading surface so multiple controls can move at once without SwiftUI gesture arbitration getting in the way

### Mock Server

- `MockServer/MockColorBoxApplication.swift`
  - Vapor app exposing the TrackGrade-facing ColorBox surface
- `MockServer/MockColorBoxState.swift`
  - in-memory mock device state
- `MockServer/MockColorBoxBonjourAdvertiser.swift`
  - publishes `_http._tcp` for local discovery work

## Runtime Data Flow

### 1. Discovery And Device Registration

1. `TrackGradeAppModel.start(modelContext:)` boots discovery and reloads persisted devices.
2. `TrackGradeDeviceDiscovery` watches Bonjour services.
3. Saved devices are stored in SwiftData as `StoredColorBoxDevice`.
4. Passwords stay in Keychain and are referenced from SwiftData by opaque ID.

### 2. Device Connection

1. `TrackGradeAppModel` registers devices with `DeviceManager`.
2. `DeviceManager` resolves the endpoint and creates a `ColorBoxAPIClient`.
3. `connect(id:)` fan-outs a refresh for:
   - system info
   - firmware info
   - pipeline state
   - preset list
   - preview frame
4. Results are merged into `ManagedColorBoxDevice`, then published through `snapshotStream()`.

### 3. Grade Interaction

1. `GradeFeatureView` renders a fixed landscape surface.
2. Touch gestures mutate local draft grade state immediately for responsive UI feedback.
3. Changes are coalesced and sent through `TrackGradeAppModel.updateGradeControl`.
4. `DeviceManager` writes the current LGG/S state to `/v2/pipelineStages`.
5. The distinct `Before / After` compare control temporarily flips bypass, remembers the original device state, and restores it when compare mode ends.
6. Undo / redo checkpoints are recorded at interaction boundaries instead of every touch sample.

### 3a. Dynamic LUT Bake And Upload Path

The repo now also contains the Phase 3 bake/upload path even though it is not yet the default live grading route:

1. `ColorBoxGradeControlState` converts to `GradeState`
2. `GradeState` converts to `CDLValues`
3. `LUTBaker` emits a `CubeLUT`
4. `CubeLUT.serialize()` produces `.cube` text
5. `DeviceManager` enqueues that payload into a per-device `DynamicLUTUploadQueue`
6. the queue keeps only the newest pending payload while one upload is in flight

This keeps the UI-side architecture ready for the brief’s intended dynamic-LUT workflow without forcing the unresolved live firmware upload path into the shipping hardware route prematurely.

### 4. Preset Workflow

1. Preset save calls `POST /v2/saveDynamicLutRequest`.
2. TrackGrade then stores the device preset slot and applies the friendly name through `/v2/libraryControl`.
3. Preset recall refreshes pipeline state after the device-side recall action.
4. Local snapshots are intentionally separate from device-native presets.

### 5. Gang Broadcast Workflow

1. The selected device remains the focus device shown in the grading surface.
2. Any saved devices marked as ganged in the device list become linked peers.
3. Grade changes, bypass, false color, pipeline configuration, and preset recall broadcast from the focused device to those linked peers.
4. The grading header compares the focused device state to linked peers and surfaces a synced, waiting, or drifted badge.

## Persistence Model

### SwiftData

- `StoredColorBoxDevice`
  - device name
  - address
  - username
  - credential reference
  - per-device working transfer function
- `StoredGradeSnapshot`
  - device association
  - name
  - kind (`standard`, scratch A, scratch B)
  - preview thumbnail bytes
  - captured `ColorBoxGradeControlState`

### Keychain

- stores credentials keyed by the SwiftData device record's credential reference

## Offline Test Fixture Mode

When the app launches with `-ui-test-fixture`:

- SwiftData uses an in-memory store
- three connected fixture ColorBoxes are seeded
- presets, snapshots, and bypass mutate locally
- UI tests can validate the real grading shell and first-pass gang behavior without LAN or hardware

This keeps the simulator and UI automation path close to the real app shell instead of using a completely separate demo mode.

## Error Handling And Resilience

- `DeviceManager` models connection state as `disconnected`, `connecting`, `connected`, `degraded`, or `error`
- reconnects use exponential backoff
- the app keeps showing the latest local grade state while reconnection is in progress
- false color is treated as a capability issue, not a transport failure, on unsupported firmware

## Current Architectural Constraints

- The app currently drives live grade directly through `pipelineStages` instead of routing live iPad gestures through the baked `.cube` upload path, because the reference firmware’s `/v2/upload` materialization semantics are still unresolved.
- Gang control currently follows a focused-device-plus-linked-peers model; deeper workflow support such as per-device offsets and richer gang management is still future work.
- Single-file device library management is live-verified for 1D LUT, 3D LUT, matrix, image, and overlay assets.
- AMF import is wired through the committed `/v2/uploadMultiple` contract and validated against the mock server, but successful hardware verification is still pending because the reference box is not currently reachable from this host.
- The project compiles shared sources in both the app target and the package; a later cleanup can consume the local package product more directly.

## Testing Strategy

- `swift test`
  - shared models
  - integration tests against `MockColorBox`
  - generated-client smoke checks
- `xcodebuild test`
  - iPad app launch and workflow coverage in fixture mode

See `Docs/TEST-PLAN.md` for release-gate and manual-hardware validation details.
