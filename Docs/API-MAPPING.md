# API Mapping

## Current Status

- The live OpenAPI document was fetched from `http://172.29.14.51/api/openapi.yaml` on 2026-04-21 and committed to [openapi-colorbox.json](/Users/bob/dev/TrackGrade/Docs/openapi-colorbox.json) and [openapi-colorbox.yaml](/Users/bob/dev/TrackGrade/Docs/openapi-colorbox.yaml).
- The real device is serving firmware/app version `3.0.0.24` via `GET /v2/buildInfo` and `GET /v2/system/status`.
- The reference ColorBox currently reports `authenticationEnable: false` from `GET /v2/system/config`, so read and write requests on this box do not presently require credentials.
- The live contract uses server base `'/v2'`, which means the provisional `/system/info`-style paths in the handwritten mock and wrapper do not match the real device surface.
- The document declares an API key security scheme named `app_id` carried in the `X-API-KEY` header.
- TrackGrade now uses the generated `/v2` client for connect-time reads plus pipeline-node configuration and bypass writes, with the older handwritten endpoints retained as fallback compatibility paths.

## TODO

- Identify the real false-color control path, or explicitly downgrade false color on ColorBox firmware `3.0.0.24`.
- Replace the remaining provisional mutation routes after the live write semantics are verified.

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
| Pipeline stage configuration | `GET` / `PUT` | `/v2/pipelineStages` | Includes `lut3d_1.dynamic`, `enabled`, and library entry selections |
| Preview image | `GET` | `/v2/preview` | Returns JSON `Preview` object with base64 image data |
| Preset library list | `GET` | `/v2/systemPresetLibrary` | Returns `LibraryEntry` array |
| Library control | `GET` / `PUT` | `/v2/libraryControl` | Verified live for preset save / rename / recall / delete |
| LUT upload | `POST` | `/v2/upload` | Multipart form upload with `kind` such as `lut_3d` |
| Save current dynamic LUT | `POST` | `/v2/saveDynamicLutRequest` | Explicitly writes flash; spec warns to use sparingly |

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
| Bypass toggle | `GET /v2/routing` then `PUT /v2/routing` |
| Preset save | `PUT /v2/libraryControl` with `StoreEntry`, then `SetUserName`, then `GET /v2/systemPresetLibrary` |
| Preset recall | `PUT /v2/libraryControl` with `RecallEntry`, then refresh routing / pipeline state |
| Preset delete | `PUT /v2/libraryControl` with `DeleteEntry`, then `GET /v2/systemPresetLibrary` |
| False color toggle | Falls back to provisional mock route only for now; live `/v2` mapping still not found |

## Verified Live Preset Semantics

TrackGrade now has live-verified behavior for device-native presets on firmware `3.0.0.24`:

- `StoreEntry` alone writes the slot contents but does not make a friendly preset name visible in `GET /v2/systemPresetLibrary`.
- `SetUserName` on the same slot is required to surface the saved preset name in the library listing.
- `RecallEntry` successfully restores saved pipeline state when the slot contains a valid stored preset.
- `DeleteEntry` removes the preset from the library listing cleanly.
- `RecallEntry` against the pre-existing slot 1 (`current-show`) returned a device-side error on this box: `"Internal problems recalling preset"`, which suggests that not every listed preset is necessarily recallable.

## False Color Status

- No dedicated false-color endpoint has been identified in the live `/v2` contract for firmware `3.0.0.24`.
- A follow-up pass across the device’s shipped web UI bundles exposed `routing`, `pipelineStages`, `libraryControl`, `systemPresetLibrary`, `preview`, and related configuration routes, but still did not reveal a false-color control path.
- TrackGrade should currently treat false color as unsupported on firmware `3.0.0.24` unless a future firmware or vendor reference reveals the correct API surface.

## Authentication Status

- The reference ColorBox reports `authenticationEnable: false`.
- The user has confirmed that authentication will remain disabled for the foreseeable future.
- TrackGrade keeps transport-level support for credentials, but API-key entry is no longer a Phase 1 requirement for this hardware.
