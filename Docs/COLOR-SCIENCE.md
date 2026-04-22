# Color Science

## Current State

TrackGrade's current shipping path is intentionally narrower than the original long-term brief. On the reference ColorBox firmware used during development, the app currently drives grading by writing directly to the device's `lut3d_1.colorCorrector` and `procAmp.sat` fields through `PUT /v2/pipelineStages`.

That means:

- live Lift / Gamma / Gain and saturation control is real and hardware-verified
- device-native preset save is real and hardware-verified
- LUT baking and `.cube` upload are not the active MVP path in this build

The `Core/ColorMath` module remains the landing zone for fuller CDL math and LUT baking, but today it primarily contains the shared grade model types and transfer-function enum scaffolding.

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

This mirrors the way the current ColorBox `/v2/pipelineStages` surface represents the live grade controls that TrackGrade is writing.

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

These are interaction-space guardrails for the current direct-device path. They are not yet presented as a formal ASC-CDL implementation.

## Transfer Functions

`TransferFunction.swift` currently defines:

- `Rec.709 SDR`
- `Rec.709 HLG`

The enum is in place so the app and future baking path can share a durable vocabulary, but the current MVP does not yet:

- linearize samples
- apply CDL in linear light
- re-encode into a baked LUT

That fuller path remains future work.

## Device Pipeline Mapping

The live grade path currently writes:

- Lift to `lut3d_1.colorCorrector.black*`
- Gamma to `lut3d_1.colorCorrector.gamma*`
- Gain to `lut3d_1.colorCorrector.gain*`
- Saturation to `lut3d_1.procAmp.sat`

TrackGrade first ensures that the 3D LUT stage is configured for dynamic mode, then keeps writing the grade state back through `/v2/pipelineStages`.

## Preset Persistence Implication

On the reference firmware, device-native preset persistence of the current dynamic grade requires:

1. `POST /v2/saveDynamicLutRequest`
2. `PUT /v2/libraryControl` with `StoreEntry`
3. `PUT /v2/libraryControl` with `SetUserName`

Without the `saveDynamicLutRequest` step, recalling a preset can return identity/default values instead of the current dynamic grade.

## Planned LUT Path

The long-term brief still calls for:

- formal ASC-CDL math
- transfer-function-aware linear processing
- baking a `33^3` LUT
- serializing `.cube`
- uploading the result to the ColorBox dynamic LUT slot

That path is not the active implementation today because the reference firmware already exposes a reliable direct-grade control path and the live `/v2/upload` library materialization behavior remains unresolved on the tested device.

## Testing Expectations

Current automated coverage includes:

- identity model defaults
- trackball mapping round trips
- clamping behavior
- integration tests proving the mock and the app can round-trip live grade values through the device-facing API surface

The fuller color-math phase should eventually expand this with:

- ASC-CDL vector tests
- transfer-function tests
- LUT bake correctness tests
- performance timing checks for bake + serialization
