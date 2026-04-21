# Open Questions

1. The reference ColorBox currently reports `authenticationEnable: false`, so we are not blocked on credentials for this box. Do you still want API-key entry surfaced in v1 for future authenticated hardware, or can that UI wait until after Phase 1 acceptance?
2. The live `/v2` spec does not expose a dedicated false-color endpoint matching the brief’s assumed `/pipeline/false-color` route. Should TrackGrade treat false color as unsupported on firmware `3.0.0.24` unless we identify another control path, or do you know where that capability lives on this box?
3. The live `/v2` contract exposes preset listing through `GET /systemPresetLibrary`, but save / recall / delete semantics are not yet explicit. Are you comfortable with me probing preset mutations on the live box to discover the correct mapping, or should I keep that work constrained to the mock until we know the safe operation path?
