# API Mapping

## TODO

- Fetch the live ColorBox OpenAPI JSON from the reference device at `172.29.14.51` once its HTTP interface is reachable from this Mac.
- Commit the fetched specification to `Docs/openapi-colorbox.json`.
- Generate the typed client with `swift-openapi-generator`.
- Cross-reference every TrackGrade endpoint usage against the committed spec before Phase 1 integration work.

## Current Status

- Bonjour discovery confirms a ColorBox service named `ColorBox-1SC001145` on `_http._tcp.local` at `172.29.14.51:80`.
- Direct HTTP/TCP access from this development machine is currently failing with `No route to host` / `host-unreach`, so the live spec cannot yet be fetched.
