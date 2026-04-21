# Open Questions

1. `POST /v2/upload` on firmware `3.0.0.24` returns `200` from the reference ColorBox, but the uploaded LUT does not appear in `GET /v2/3dLutLibrary`. Should this be treated as a firmware quirk to keep reverse-engineering around, or do you want me to defer live LUT import until we have vendor guidance or a newer firmware to test?
