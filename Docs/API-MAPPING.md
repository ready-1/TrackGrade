# API Mapping

## Current Status

- The live OpenAPI document was fetched from `http://172.29.14.51/api/openapi.yaml` on 2026-04-21 and committed to [openapi-colorbox.json](/Users/bob/dev/TrackGrade/Docs/openapi-colorbox.json) and [openapi-colorbox.yaml](/Users/bob/dev/TrackGrade/Docs/openapi-colorbox.yaml).
- The real device is serving firmware/app version `3.0.0.24` via `GET /v2/buildInfo` and `GET /v2/system/status`.
- The live contract uses server base `'/v2'`, which means the provisional `/system/info`-style paths in the handwritten mock and wrapper do not match the real device surface.
- The document declares an API key security scheme named `app_id` carried in the `X-API-KEY` header.

## TODO

- Generate the typed client with `swift-openapi-generator` from the committed live spec.
- Replace the handwritten request wrapper with generated client calls once the auth and endpoint-mapping questions are settled.
- Update the mock server so its route surface matches the real `/v2` hardware contract closely enough for Phase 1 parity testing.

## Live Endpoint Surface

The following endpoints are the real hardware routes currently relevant to TrackGrade. This table intentionally focuses on Phase 1 connectivity work rather than every endpoint in the device spec.

| Capability | Method | Path | Notes |
| --- | --- | --- | --- |
| Fetch OpenAPI UI | `GET` | `/api/index.html` | Swagger UI page discovered on the live device |
| Fetch OpenAPI source | `GET` | `/api/openapi.yaml` | Source of truth committed under `Docs/` |
| Build / firmware info | `GET` | `/v2/buildInfo` | Returns app version, build type, repo hash, build date |
| System status | `GET` | `/v2/system/status` | Returns running / boot versions and transform-mode state |
| Global device status | `GET` | `/v2/status` | Larger system-wide status object |
| Routing / bypass state | `GET` / `PUT` | `/v2/routing` | Contains `pipelineBypassButton` and `pipelineBypassUser` |
| Pipeline stage configuration | `GET` / `PUT` | `/v2/pipelineStages` | Includes `lut3d_1.dynamic`, `enabled`, and library entry selections |
| Preview image | `GET` | `/v2/preview` | Returns JSON `Preview` object with base64 image data |
| Preset library list | `GET` | `/v2/systemPresetLibrary` | Returns `LibraryEntry` array |
| Library control | `GET` / `PUT` | `/v2/libraryControl` | Likely used for some library operations; needs mapping confirmation |
| LUT upload | `POST` | `/v2/upload` | Multipart form upload with `kind` such as `lut_3d` |
| Save current dynamic LUT | `POST` | `/v2/saveDynamicLutRequest` | Explicitly writes flash; spec warns to use sparingly |

## Divergences From The Provisional Wrapper

- `ColorBoxAPIClient.fetchSystemInfo()` and `fetchFirmwareInfo()` were built around guessed `/system/info` and `/system/firmware` routes, but the real spec exposes `GET /v2/buildInfo` and `GET /v2/system/status`.
- The real pipeline model is represented as `PipelineStages` and `Routing`, not `pipeline/state` plus dedicated bypass / false-color endpoints.
- Preview fetches are JSON objects with base64 image payloads, not raw image bytes from `/preview/frame`.
- Presets are exposed as a library array and likely controlled through library operations, not `GET/POST/DELETE /presets/*`.
- Dynamic LUT replacement appears to involve `POST /v2/upload` and related library / stage selection state, not a direct `PUT /pipeline/aja/nodes/3dlut/dynamic`.

## Open Questions From The Live Spec

- The spec documents `X-API-KEY` auth, but the current app shell only models username/password credentials.
- No dedicated false-color endpoint has been identified in the live contract yet.
