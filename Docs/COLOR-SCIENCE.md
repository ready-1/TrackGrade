# Color Science

## Current State

TrackGrade now has two closely related color-processing layers in the repo:

1. A real hardware-backed MVP path that configures the dynamic 3D LUT stage, converts live control state into ASC-CDL values, bakes a `.cube` LUT, and sends that payload over `ws://<host>:5000`
2. A full offline and mock-verified Phase 3 color-math path that exercises the same control-state-to-CDL-to-LUT pipeline while using the compatibility HTTP endpoint instead of the real socket ingest

That means the app is already usable on the reference ColorBox today, and the same bake/upload path exists in durable code and tests for offline validation.

For the current build:

- live Lift / Gamma / Gain and saturation control is real and hardware-verified on iPad + ColorBox hardware
- device-native preset save is real and hardware-verified
- LUT baking and queued upload are implemented in `Core/ColorMath` and `Core/DeviceManager`
- the app shell uses the hardware-verified dynamic-LUT WebSocket path on real hosts instead of trying to grade through `/v2/upload`

## Grade Representation

The app's interactive grade model is `ColorBoxGradeControlState`:

- `lift`: `ColorBoxRGBVector`
- `gamma`: `ColorBoxRGBVector`
- `gain`: `ColorBoxRGBVector`
- `saturation`: `Float`

Identity is:

- lift = `(0, 0, 0)`
- gamma = `(0, 0, 0)`
- gain = `(1, 1, 1)`
- saturation = `1.0`

This mirrors the way TrackGrade represents the live grade controls that it converts into a dynamic LUT for real-host playback and into mock-compatible metadata for offline testing.

`GradeState` in `Core/ColorMath/CDL.swift` is the bridge from that interactive control model into formal CDL values:

- Lift becomes CDL `Offset`
- Gamma becomes CDL `Power`
- Gain becomes CDL `Slope`
- saturation maps directly to CDL saturation with a hard clamp of `0.0 ... 2.0`

## Trackball Mapping

Trackball interaction is converted into RGB vectors through `ColorBoxTrackballMapping` in `Core/ColorBoxAPI/ColorBoxModels.swift`.

### Ball Mapping

Given a 2D point `(x, y)` constrained to the unit disk:

- magnitude = `sqrt(x² + y²)`
- angle = `atan2(y, x)`

TrackGrade derives an RGB tint vector with 120°-separated phase offsets:

- `R = magnitude * scale * cos(angle)`
- `G = magnitude * scale * cos(angle - 120°)`
- `B = magnitude * scale * cos(angle - 240°)`

Current per-control chroma scales:

- Lift ball: `0.18`
- Gamma ball: `0.25`
- Gain ball: `0.22`

### Ring Mapping

The outer ring contributes a uniform luminance-style value added to each channel after removing or restoring the neutral point for that control.

Current ring scales:

- Lift ring: `0.5`
- Gamma ring: `0.5`
- Gain ring: `1.0`

Neutral values:

- Lift: `0`
- Gamma: `0`
- Gain: `1`

### Working Ranges In The Current UI Path

- Lift channels clamp to `-0.75 ... 0.75`
- Gamma channels clamp to `-1.0 ... 1.0`
- Gain channels clamp to `0.0 ... 2.0`
- Saturation is adjusted around `1.0`

These interaction-space controls are also converted into CDL space through `GradeState.toCDL()`:

- Lift ring maps to luminance offset in `[-0.2, 0.2]`
- Lift ball adds chromatic offset with scale `0.1`
- Gamma ring maps exponentially to power in `[0.2, 5.0]`
- Gamma ball adds per-channel power bias with scale `0.2`
- Gain ring maps piecewise to slope in `[0.0, 4.0]`
- Gain ball adds per-channel slope bias with scale `0.2`

## Transfer Functions

`TransferFunction.swift` defines:

- `Rec.709 SDR`
- `Rec.709 HLG`

These are real encode / decode implementations, not placeholders:

- `toLinear(_:)` clamps code values into `0 ... 1` and linearizes them
- `fromLinear(_:)` clamps linear-light values into `0 ... 1` and re-encodes them

The CDL bake path uses these transfer functions as:

1. input code-value sample
2. linearize
3. apply CDL `Slope / Offset / Power`
4. apply saturation in linear light using Rec.709 luma weights
5. re-encode
6. clamp and emit to `.cube`

Current automated tests cover round-trip accuracy across the sample ramp for both transfer functions.

## CDL Implementation

`CDLValues` now implements the brief’s intended processing shape:

- `(linear * slope) + offset`
- clamp to `0 ... 1`
- apply inverse power exponent `1 / power`
- compute Rec.709 luma using weights `0.2126 / 0.7152 / 0.0722`
- apply saturation around that luma
- clamp result back into `0 ... 1`

Current tests cover:

- identity behavior
- inverse-power and saturation application in linear light
- power and saturation clamping
- helper conversions from `ColorBoxGradeControlState`

## LUT Baking And Serialization

`LUTBaker` now produces real Iridas `.cube` output:

- default size: `33`
- domain: `0 ... 1`
- entry order: red-inner, green-middle, blue-outer
- default title: `TrackGrade <timestamp>`

`CubeLUT` handles:

- durable in-memory representation
- `.cube` serialization
- parsing back from serialized text
- parse error reporting for missing size, invalid headers, invalid rows, and unexpected entry counts

Current tests cover:

- identity-corner preservation
- serialization round-trip symmetry
- parser failure cases
- default timestamp title generation

## Device Pipeline Mapping

The live grade path currently:

- configures `lut3d_1` as the active dynamic stage through `/v2/pipelineStages`
- converts `ColorBoxGradeControlState` into `GradeState` / `CDLValues`
- bakes a `33^3` LUT
- sends the binary payload over `ws://<host>:5000`
- preserves the requested grade locally in app state for UI continuity and uses stage reads for configuration/readback

In parallel, `DeviceManager` now also exposes a `DynamicLUTUploadQueue` for per-device queued `.cube` uploads:

- one in-flight upload per device
- newest pending upload replaces older pending uploads
- `flush()` waits until the queue is drained
- each upload carries a monotonic `X-TrackGrade-Sequence` header for debugging

This matches the brief’s last-write-wins upload model and now also backs the verified real-host grading route.

## Preset Persistence Implication

On the reference firmware, device-native preset persistence of the current dynamic grade requires:

1. `POST /v2/saveDynamicLutRequest`
2. `PUT /v2/libraryControl` with `StoreEntry`
3. `PUT /v2/libraryControl` with `SetUserName`

Without the `saveDynamicLutRequest` step, recalling a preset can return identity/default values instead of the current dynamic grade.

## Live Upload Status

The remaining live-upload gap is specifically about library-style `POST /v2/upload` asset management, not about real-time grading:

- the reference ColorBox accepts `POST /v2/upload`
- the device web UI uses the same route for library asset import
- TrackGrade’s real-time grading path does not depend on that library-materialization behavior

The shipping grading path is the hardware-verified WebSocket dynamic-LUT ingest, while `POST /v2/upload` remains relevant for library management and future deeper validation.

## Testing Expectations

Current automated coverage includes:

- transfer-function round trips
- out-of-range clamping
- identity CDL behavior
- linear-light power and saturation application
- control-state-to-CDL conversion
- `.cube` serialization and parser failures
- identity LUT bake correctness
- mock-backed dynamic LUT upload and queue coalescing

Current measured acceptance evidence:

- `Core/ColorMath` line coverage: `92.71%`
- release-mode `33^3` identity bake timing check: passed under the brief’s `< 16 ms` target on the development Mac
