# API Mapping

## TODO

- Fetch the live ColorBox OpenAPI JSON from the reference device at `172.29.14.51` once its HTTP interface is reachable from this Mac.
- Commit the fetched specification to `Docs/openapi-colorbox.json`.
- Generate the typed client with `swift-openapi-generator`.
- Replace the handwritten request wrapper with generated client calls once the committed spec is available.

## Current Status

- Bonjour discovery confirms a ColorBox service named `ColorBox-1SC001145` on `_http._tcp.local` at `172.29.14.51:80`.
- Direct HTTP/TCP access from this development machine is currently failing with `No route to host` / `host-unreach`, so the live spec cannot yet be fetched.

## Current Endpoint Surface

The following routes are implemented in `Core/ColorBoxAPI/ColorBoxAPIClient.swift` and mirrored by the in-process `MockColorBox` Vapor server. These route assumptions are provisional until the live OpenAPI document is fetched from the real device.

| Capability | Method | Path | Current caller |
| --- | --- | --- | --- |
| Fetch OpenAPI document | `GET` | `/api` | `fetchOpenAPIDocument()` |
| Fetch system info | `GET` | `/system/info` | `fetchSystemInfo()` |
| Fetch firmware info | `GET` | `/system/firmware` | `fetchFirmwareInfo()` |
| Fetch pipeline state | `GET` | `/pipeline/state` | `fetchPipelineState()` |
| Configure node 4 for dynamic LUTs | `PATCH` | `/pipeline/aja/nodes/3dlut/dynamic` | `configureDynamicLUTNode()` |
| Upload dynamic LUT text | `PUT` | `/pipeline/aja/nodes/3dlut/dynamic` | `uploadDynamicLUT(cubeText:sequenceID:)` |
| Toggle pipeline bypass | `PATCH` | `/pipeline/bypass` | `setBypass(_:)` |
| Toggle false color | `PATCH` | `/pipeline/false-color` | `setFalseColor(_:)` |
| List presets | `GET` | `/presets` | `listPresets()` |
| Save preset | `POST` | `/presets/save` | `savePreset(slot:name:)` |
| Recall preset | `POST` | `/presets/recall` | `recallPreset(slot:)` |
| Delete preset | `DELETE` | `/presets/{slot}` | `deletePreset(slot:)` |
| Fetch preview frame | `GET` | `/preview/frame` | `fetchPreviewFrame()` |
