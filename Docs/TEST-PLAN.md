# Test Plan

## Purpose

This plan defines the current verification path for TrackGrade across package tests, app-level simulator tests, and the remaining manual hardware checks against a live AJA ColorBox.

## Automated Checks

Run these from the repo root:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project TrackGrade.xcodeproj \
  -scheme TrackGrade \
  -destination 'platform=iOS Simulator,name=iPad (A16),OS=latest' \
  CODE_SIGNING_ALLOWED=NO \
  test
```

When a reference ColorBox is reachable, run the reversible live integration checks with:

```sh
TRACKGRADE_LIVE_COLORBOX_HOST=172.29.14.51 \
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
swift test --filter TrackGradeIntegrationTests/testLiveColorBox
```

Phase 3 acceptance evidence is collected with:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --enable-code-coverage
xcrun llvm-cov report \
  .build/arm64-apple-macosx/debug/TrackGradeCorePackageTests.xctest/Contents/MacOS/TrackGradeCorePackageTests \
  -instr-profile .build/arm64-apple-macosx/debug/codecov/default.profdata \
  -ignore-filename-regex='^(/Users/bob/dev/TrackGrade/.build|/Applications/Xcode)' \
  Core/ColorMath/CDL.swift \
  Core/ColorMath/TransferFunction.swift \
  Core/ColorMath/CubeLUT.swift \
  Core/ColorMath/LUTBaker.swift
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  swift test -c release --filter LUTBakerPerformanceTests/testReleaseBakeCompletesUnderSixteenMilliseconds
```

Current automated coverage:

- Generated ColorBox client smoke tests
- Trackball mapping and core grade-control helpers
- Color math coverage for CDL application, transfer functions, `.cube` parsing / serialization, LUT baking, and helper conversions
- Mock-server integration for connect, preview, device library reads and mutations, bypass, presets, reconnect, and unsupported false color
- Mock-server integration for identity LUT upload and last-write-wins queue coalescing
- Opt-in live integration for grade / bypass / preview round-trips, preset lifecycle, and `3D LUT` library lifecycle against the reference ColorBox
- Fixture-backed iPad UI flows for launch, bypass, Before / After compare, settings, preset save, snapshot save, snapshot recall, gang broadcast, and library management
- Fixture-backed iPad UI flows for preview source toggle and enlarged preview presentation
- Fixture-backed hit-region accessibility audit for the static control surface

Current measured Phase 3 acceptance evidence:

- `Core/ColorMath` line coverage: `92.71%`
- release-mode `33^3` LUT bake timing check: passed under the `< 16 ms` target

## Offline Simulator Validation

Use the `-ui-test-fixture` launch argument on the `TrackGrade` scheme to boot into the seeded offline control surface without live hardware.

Manual simulator checks:

- Launch in landscape and confirm the grade surface is fixed with no vertical scrolling
- Toggle `Before / After` and confirm it temporarily flips bypass, then restores the prior state
- Verify saturation sits above the trackballs
- Verify reset controls remain visible for Lift, Gamma, Gain, and Saturation
- Tap the preview thumbnail and confirm it flips between `Output` and `Input`
- Use the expand preview control and confirm the enlarged preview sheet opens and closes cleanly
- Open the drawer and confirm the `Workflow`, `Presets`, and `Device` panels switch cleanly
- Open the library browser and confirm seeded 16-slot library sections and entries appear
- Confirm an empty supported library slot exposes an `Import` action
- In fixture or mock-backed AMF flows, confirm the `.amf` payload is the selected import file even when companion files are present
- Delete a seeded fixture library entry and confirm the slot returns to an empty importable state
- Link at least two fixture peers from the device list and confirm bypass mirrors to them
- Save and recall a snapshot from fixture mode
- Save a device preset from fixture mode
- If the bake/upload path is exposed in a later build, verify that the newest pending LUT wins under rapid repeated grade changes

## Manual Hardware Validation

These checks still require a real iPad and the reference ColorBox.

### Device Connection

- Connect to the reference ColorBox and confirm the app reads device identity, preview, and pipeline state
- Confirm the preview thumbnail switches the hardware between `OUTPUT` and `INPUT` taps and refreshes the frame
- Confirm bypass toggles live on the device
- Confirm Lift / Gamma / Gain / Saturation changes round-trip without drift after refresh
- Once the real upload path is re-enabled, confirm finger-up results in the final baked LUT matching the visible UI state on-device

### Touch Surface

- Validate simultaneous multi-touch on multiple trackballs
- Validate ring and ball gestures independently for each LGG control
- Tune sensitivities if the live surface feels over-responsive or sluggish
- Confirm double-tap reset interactions are easy to trigger intentionally but hard to trigger accidentally

### Presets And Snapshots

- Save a ColorBox-resident preset after grading changes
- Recall the saved preset on the hardware and confirm the grade state restores correctly
- Delete a preset and confirm it disappears from the device library
- Verify local snapshots and scratch slots do not interfere with device-native preset behavior
- Import a test asset into an empty 1D LUT, 3D LUT, matrix, image, or overlay slot, confirm it appears in the library, rename it, and then delete it cleanly
- Import an AMF package through the multi-file picker, confirm the selected `.amf` file becomes the device library entry, and then delete it cleanly

### Gang Validation

- Link at least two real ColorBox peers to the focused device
- Confirm bypass and grade changes propagate to all linked peers
- Confirm the sync badge reports drift if one linked peer is changed out-of-band
- Confirm returning the drifted device to the same grade clears the drift indicator

## Release Gate

The current repo is ready for offline development and simulator verification when both automated commands above pass.

The project is ready for a first hardware-backed release candidate only after:

- The manual hardware checks above pass on an iPad with the live ColorBox
- The final touch sensitivities are accepted
- Placeholder signing metadata is replaced when Apple Developer access is restored
