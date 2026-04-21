# Open Questions

1. The live ColorBox OpenAPI document is now reachable, and it declares `X-API-KEY` header authentication (`app_id`) rather than Basic Auth. What API key should TrackGrade use for mutating calls on `172.29.14.51`?
2. The live `/v2` spec does not expose a dedicated false-color endpoint matching the brief’s assumed `/pipeline/false-color` route. Should TrackGrade treat false color as unsupported on firmware `3.0.0.24` unless we identify another control path, or do you know where that capability lives on this box?
