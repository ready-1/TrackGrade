# API Mapping

## Current Status

- The live OpenAPI document was fetched from `http://172.29.14.51/api/openapi.yaml` on 2026-04-21 and committed to [openapi-colorbox.json](/Users/bob/dev/TrackGrade/Docs/openapi-colorbox.json) and [openapi-colorbox.yaml](/Users/bob/dev/TrackGrade/Docs/openapi-colorbox.yaml).
- The real device is serving firmware/app version `3.0.0.24` via `GET /v2/buildInfo` and `GET /v2/system/status`.
- The reference ColorBox currently reports `authenticationEnable: false` from `GET /v2/system/config`, so read and write requests on this box do not presently require credentials.
- The live contract uses server base `'/v2'`, which means the provisional `/system/info`-style paths in the handwritten mock and wrapper do not match the real device surface.
- The document declares an API key security scheme named `app_id` carried in the `X-API-KEY` header.
- TrackGrade now uses the generated `/v2` client for connect-time reads plus pipeline-node configuration and bypass writes, with the older handwritten endpoints retained as fallback compatibility paths.
- Package-side generated-client validation must use a server URL shaped like `http://host/v2` without a trailing slash; using `http://host/v2/` produces broken `/v2//...` requests on real hardware.

## TODO

- Decide whether the mock-validated baked dynamic-LUT upload path should remain internal until a live grading workflow based on uploads is intentionally adopted.

## Live Endpoint Surface

The following endpoints are the real hardware routes currently relevant to TrackGrade. This table intentionally focuses on Phase 1 connectivity work rather than every endpoint in the device spec.

| Capability | Method | Path | Notes |
| --- | --- | --- | --- |
| Fetch OpenAPI UI | `GET` | `/api/index.html` | Swagger UI page discovered on the live device |
| Fetch OpenAPI source | `GET` | `/api/openapi.yaml` | Source of truth committed under `Docs/` |
| Build / firmware info | `GET` | `/v2/buildInfo` | Returns app version, build type, repo hash, build date |
| System config | `GET` | `/v2/system/config` | Includes `hostName`, `transformMode`, `startupPreset`, and `authenticationEnable` |
| System status | `GET` | `/v2/system/status` | Returns running / boot versions and transform-mode state |
| Global device status | `GET` | `/v2/status` | Larger system-wide status object |
| Routing / bypass state | `GET` / `PUT` | `/v2/routing` | Contains `pipelineBypassButton` and `pipelineBypassUser` |
| Pipeline stage configuration | `GET` / `PUT` | `/v2/pipelineStages` | Includes `lut3d_1.dynamic`, `enabled`, library entry, `colorCorrector`, and `procAmp` |
| Preview image | `GET` | `/v2/preview` | Returns JSON `Preview` object with base64 image data |
| Preset library list | `GET` | `/v2/systemPresetLibrary` | Returns `LibraryEntry` array |
| 1D LUT library | `GET` | `/v2/1dLutLibrary` | Returns the 1D LUT slot array |
| 3D LUT library | `GET` | `/v2/3dLutLibrary` | Returns the 3D LUT slot array |
| Matrix library | `GET` | `/v2/matrixLibrary` | Returns the matrix slot array |
| Image library | `GET` | `/v2/imageLibrary` | Returns the image slot array |
| Overlay library | `GET` | `/v2/overlayLibrary` | Returns the overlay slot array |
| AMF library | `GET` | `/v2/amfLibrary` | Returns the AMF slot array |
| Library control | `GET` / `PUT` | `/v2/libraryControl` | Verified live for preset save / rename / recall / delete |
| LUT upload | `POST` | `/v2/upload` | Multipart form upload with `kind` such as `lut_3d`; route verified live for library import semantics |
| AMF upload | `POST` | `/v2/uploadMultiple` | Multipart form upload with repeated `file` parts plus `kind=amf`, `entry`, and `selection` |
| Save current dynamic LUT | `POST` | `/v2/saveDynamicLutRequest` | Live route verified; required before preset store when the current dynamic grade should survive recall |

## Divergences From The Provisional Wrapper

- `ColorBoxAPIClient.fetchSystemInfo()` and `fetchFirmwareInfo()` were built around guessed `/system/info` and `/system/firmware` routes, but the real spec exposes `GET /v2/buildInfo` and `GET /v2/system/status`.
- The real pipeline model is represented as `PipelineStages` and `Routing`, not `pipeline/state` plus dedicated bypass / false-color endpoints.
- Preview fetches are JSON objects with base64 image payloads, not raw image bytes from `/preview/frame`.
- Presets are exposed as a library array and are controlled through `GET/PUT /v2/libraryControl`, not `GET/POST/DELETE /presets/*`.
- Dynamic LUT replacement appears to involve `POST /v2/upload` and related library / stage selection state, not a direct `PUT /pipeline/aja/nodes/3dlut/dynamic`.

## TrackGrade Mappings In Code

These are the concrete mappings currently implemented in the codebase:

| TrackGrade action | Current implementation |
| --- | --- |
| Connect device summary | `GET /v2/buildInfo` + `GET /v2/system/config` |
| Firmware summary | `GET /v2/buildInfo` + `GET /v2/system/status` |
| Bypass state read | `GET /v2/routing` |
| 3D LUT node state read | `GET /v2/pipelineStages` |
| Preset list read | `GET /v2/systemPresetLibrary` |
| Preview fetch | `GET /v2/preview` |
| Configure node 4 dynamic | `GET /v2/pipelineStages` then `PUT /v2/pipelineStages` |
| Update Lift / Gamma / Gain / Saturation | `GET /v2/pipelineStages` then `PUT /v2/pipelineStages` with `lut3d_1.colorCorrector` and `procAmp.sat` |
| Bypass toggle | `GET /v2/routing` then `PUT /v2/routing` |
| Preview source toggle | `GET /v2/routing` then `PUT /v2/routing` with `previewTap = INPUT/OUTPUT`, then `GET /v2/preview` |
| Preset save | Wait ~1 second after the most recent direct `pipelineStages` grade write, then `POST /v2/saveDynamicLutRequest`, then `PUT /v2/libraryControl` with `StoreEntry`, then `SetUserName`, then `GET /v2/systemPresetLibrary` |
| Preset recall | `PUT /v2/libraryControl` with `RecallEntry`, then refresh routing / pipeline state |
| Preset delete | `PUT /v2/libraryControl` with `DeleteEntry`, then `GET /v2/systemPresetLibrary` |
| Device library read | `GET` the corresponding `/v2/*Library` endpoint, then pad the returned entries to a 16-slot UI model |
| Device library import / replace | Single-file kinds use `POST /v2/upload`; AMF uses `POST /v2/uploadMultiple` with repeated `file` parts plus `selection`, then refresh the corresponding `/v2/*Library` endpoint |
| Device library rename | `PUT /v2/libraryControl` with `SetUserName`, then refresh the corresponding `/v2/*Library` endpoint |
| Device library delete | `PUT /v2/libraryControl` with `DeleteEntry`, then refresh the corresponding `/v2/*Library` endpoint |
| Dynamic LUT upload queue | Mock-verified via `PUT /pipeline/aja/nodes/3dlut/dynamic` with `X-TrackGrade-Sequence`; retained as an offline / compatibility path while the shipping live grading route remains `pipelineStages` |
| False color toggle | Disabled in the app on firmware `3.0.0.24`; no live `/v2` mapping found |

## Verified Live Preset Semantics

TrackGrade now has live-verified behavior for device-native presets on firmware `3.0.0.24`:

- `StoreEntry` alone writes the slot contents but does not make a friendly preset name visible in `GET /v2/systemPresetLibrary`.
- `SetUserName` on the same slot is required to surface the saved preset name in the library listing.
- `POST /v2/saveDynamicLutRequest` must be called before `StoreEntry` when the current dynamic Lift / Gamma / Gain / Saturation state should survive preset recall.
- On firmware `3.0.0.24`, direct `pipelineStages` writes need about one second of settle time before `saveDynamicLutRequest` reliably snapshots the updated dynamic grade.
- `previewTap` in `PUT /v2/routing` successfully flips the device preview source between `INPUT` and `OUTPUT`; the reference box read back the new value immediately and restored cleanly.
- `RecallEntry` successfully restores saved pipeline state when the slot contains a valid stored preset.
- `DeleteEntry` removes the preset from the library listing cleanly.
- `RecallEntry` against the pre-existing slot 1 (`current-show`) returned a device-side error on this box: `"Internal problems recalling preset"`, which suggests that not every listed preset is necessarily recallable.

## False Color Status

- No dedicated false-color endpoint has been identified in the live `/v2` contract for firmware `3.0.0.24`.
- A follow-up pass across the device’s shipped web UI bundles exposed `routing`, `pipelineStages`, `libraryControl`, `systemPresetLibrary`, `preview`, and related configuration routes, but still did not reveal a false-color control path.
- TrackGrade should currently treat false color as unsupported on firmware `3.0.0.24` unless a future firmware or vendor reference reveals the correct API surface.

## LUT Upload Status

- The shipped device web UI posts library imports to `POST /v2/upload` with multipart fields `file`, `kind`, and `entry`.
- Live hardware verification on `172.29.14.51` confirmed that `POST /v2/upload` with `kind=lut_3d` and `entry=<slot>` does materialize a new `GET /v2/3dLutLibrary` entry on firmware `3.0.0.24`.
- A second live pass confirmed that the multipart file part can be sent with `Content-Type: application/octet-stream`, matching the way TrackGrade now constructs uploads in-app.
- The same live pass also confirmed that `PUT /v2/libraryControl` with `library: "3D LUT"` supports:
  - `SetUserName` to rename the uploaded asset
  - `DeleteEntry` to remove it from the library
- A successful cleanup probe uploaded an identity `.cube` file to slot 4, renamed it to `TrackGrade Live Probe`, verified the renamed slot in `GET /v2/3dLutLibrary`, and then deleted it cleanly.
- The app now uses the same live-verified upload / rename / delete contract for 1D LUT, 3D LUT, matrix, image, and overlay libraries.
- The app now also implements the separate AMF multi-file upload contract from the committed OpenAPI document: `POST /v2/uploadMultiple` with repeated `file` parts, `kind=amf`, `entry=<slot>`, and `selection=<chosen .amf file>`.
- TrackGrade uses the selected `.amf` filename as the library entry that should be stored on-device, while still sending any companion files in the same multipart request.
- Live AMF verification is still pending: after the feature landed, the reference ColorBox timed out during the first direct `/v2/uploadMultiple` probe, so the repo currently only claims mock / contract validation for this path.
- Reversible live integration tests now pass against the reference box for:
  - grade / bypass / preview round-trips
  - preset save / recall / delete
  - `3D LUT` library upload / rename / delete
- A deeper probe also confirmed that `PUT /v2/pipelineStages` can switch `lut3d_1` into library-backed mode with `dynamic = false` and `libraryEntry = <slot>`, and the device reads that state back cleanly.
- That same probe did not yield visual proof of effect, but the reference test box now appears to have no active signal, so identical `INPUT` and `OUTPUT` preview hashes are treated as an environment caveat rather than evidence that the uploaded LUT path is ineffective.
- `POST /v2/saveDynamicLutRequest` is live on firmware `3.0.0.24`, returns `200`, and remains part of the reliable MVP preset-save workflow for dynamic grade persistence.
- The repo does now contain a working bake-and-queue path for `.cube` uploads against the mock server, including per-device last-write-wins coalescing and monotonic debug sequence IDs.
- TrackGrade still does not use `/v2/upload` as the live grading path; the shipping control surface continues to write grade changes through `PUT /v2/pipelineStages` until a baked-upload grading workflow is intentionally adopted and verified end to end.

## Dynamic Grade Control Status

- Direct writes to `lut3d_1.colorCorrector` and `lut3d_1.procAmp.sat` through `PUT /v2/pipelineStages` are live-verified on the reference hardware.
- A sanity check changed Lift and saturation on the real ColorBox, read the new values back successfully, and restored the original stage values cleanly.
- This is now the primary MVP grading path for TrackGrade.

## Preset Save Requirement For Dynamic Grade

- On firmware `3.0.0.24`, `StoreEntry` plus `SetUserName` alone is not enough to preserve the current dynamic Lift / Gamma / Gain / Saturation state.
- Calling `POST /v2/saveDynamicLutRequest` first makes later `RecallEntry` restore the saved dynamic grade values instead of returning to identity/default.
- A live verification saved a named slot, changed the active grade afterward, then recalled the slot and got the saved Lift / Gamma / Gain / Saturation values back with `lut3d_1.dynamic = true` and `libraryEntry = 0`.

## Authentication Status

- The reference ColorBox reports `authenticationEnable: false`.
- The user has confirmed that authentication will remain disabled for the foreseeable future.
- TrackGrade keeps transport-level support for credentials, but API-key entry is no longer a Phase 1 requirement for this hardware.
