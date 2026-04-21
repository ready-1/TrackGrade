# Mock ColorBox

`MockColorBox` is the local development stand-in for an AJA ColorBox. It runs as a macOS Swift executable, mirrors the provisional TrackGrade endpoint surface, and now advertises itself over Bonjour as `_http._tcp`.

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

- Serves the provisional TrackGrade endpoint surface used by `ColorBoxAPIClient`
- Stores dynamic LUT uploads in memory
- Serves a static PNG preview frame
- Supports optional HTTP Basic auth
- Publishes a Bonjour `_http._tcp` service with ColorBox-oriented TXT keys for discovery work

## Typical Development Flow

1. Start `MockColorBox`.
2. In TrackGrade, use the discovery sidebar or add the mock manually by IP and port.
3. Connect and exercise pipeline config, bypass, false color, presets, and preview fetch.

## Notes

- The mock contract remains provisional until `Docs/openapi-colorbox.json` can be fetched from the live ColorBox and the transport layer is regenerated from the real spec.
- The Bonjour TXT record is intentionally lightweight for now and may be updated once the real device advertises its exact keys.
