# Mock ColorBox

`MockColorBox` is the local development stand-in for an AJA ColorBox. It runs as a macOS Swift executable, advertises itself over Bonjour as `_http._tcp`, and now serves both the older provisional TrackGrade routes and the generated-client `/v2` read surface used by the real hardware path.

## Run It

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run MockColorBox
```

Optional environment variables:

- `MOCK_COLORBOX_HOST`
- `MOCK_COLORBOX_PORT`
- `MOCK_COLORBOX_SERVICE_NAME`
- `MOCK_COLORBOX_USERNAME`
- `MOCK_COLORBOX_PASSWORD`
- `MOCK_COLORBOX_LATENCY_MS`
- `MOCK_COLORBOX_FIRMWARE_VERSION`
- `MOCK_COLORBOX_FIRMWARE_BUILD`

## Current Behavior

- Serves the generated-client `/v2` read routes for build info, system config, system status, routing, pipeline stages, preset library, library control, and preview
- Serves `/v2/routing` and `/v2/pipelineStages` writes so bypass and dynamic-node configuration exercise the same contract shape as hardware
- Serves `PUT /v2/libraryControl` with `StoreEntry`, `SetUserName`, `RecallEntry`, and `DeleteEntry` so preset CRUD follows the live hardware contract
- Keeps the provisional TrackGrade false-color route while the live `/v2` control path is still being verified
- Stores dynamic LUT uploads in memory
- Serves a static PNG preview frame, both as raw `/preview/frame` bytes and as base64 image JSON on `/v2/preview`
- Supports optional HTTP Basic auth
- Publishes a Bonjour `_http._tcp` service with ColorBox-oriented TXT keys for discovery work

## Typical Development Flow

1. Start `MockColorBox`.
2. In TrackGrade, use the discovery sidebar or add the mock manually by IP and port.
3. Connect and exercise pipeline config, bypass, false color, presets, and preview fetch.

## Notes

- The mock now tracks the committed live `/v2` read contract closely enough for the generated client path used during device connection and refresh.
- False color remains provisional until the real `/v2` operation mapping is verified against hardware.
- The Bonjour TXT record is intentionally lightweight for now and may be updated once the real device advertises its exact keys.
