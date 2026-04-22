# Phase 2 Testing

## Automated Coverage

- `swift test` validates the shared `TrackGradeCore` package, mock-server integration, generated OpenAPI client smoke coverage, and trackball mapping helpers.
- `xcodebuild test` now runs a real `TrackGradeUITests` bundle against the iPad app.
- The UI tests launch TrackGrade with the `-ui-test-fixture` argument so the app seeds an in-memory ColorBox snapshot and never depends on live hardware.
- The UI tests explicitly rotate the simulator to landscape before assertions so the automated checks match the app's fixed landscape operating mode.

## Offline Fixture Mode

- Launch argument: `-ui-test-fixture`
- Behavior:
  - uses an in-memory SwiftData store
  - seeds one connected fixture ColorBox
  - keeps preset mutations in local fixture state
  - allows bypass, settings, and preset-save flows to run without LAN or hardware access
  - exercises the slide-over secondary-controls drawer in the same app shell used for live grading

## Simulator Test Command

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project TrackGrade.xcodeproj \
  -scheme TrackGrade \
  -destination 'platform=iOS Simulator,name=iPad (A16),OS=latest' \
  CODE_SIGNING_ALLOWED=NO \
  test
```

## Manual Checklist

- Confirm the three trackball clusters render on iPad simulator and hardware.
- Confirm the saturation roller updates the visible grade state while dragging.
- Confirm double-tap reset affordances fire only on the intended double tap.
- Confirm the settings sheet changes sensitivity values and that the control surface reflects the new feel.
- Confirm simultaneous touches across multiple control regions behave independently on real iPad hardware.
- Confirm live grading feel against a real ColorBox once hardware is available again.
