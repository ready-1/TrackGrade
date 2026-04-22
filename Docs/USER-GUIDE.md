# User Guide

## What TrackGrade Does

TrackGrade is a touch-first iPad control surface for AJA ColorBox. It is designed for fast, small live-event grading adjustments, especially Lift / Gamma / Gain plus saturation changes during IMAG workflows.

The current MVP focuses on:

- direct LGG + saturation control
- ColorBox-resident preset save / recall / delete
- bypass toggle
- focus-device gang broadcast to linked peer devices
- local snapshots, A/B scratch slots, and undo / redo

## Hardware Requirements

- iPad running iPadOS 18 or later
- AJA ColorBox on the same IPv4 LAN
- Bonjour / mDNS available if you want discovery

## First Launch

When the app opens, the left pane shows saved devices and discovered devices. The right pane shows the grading surface for the selected ColorBox.

If no device is available yet:

1. Tap `Add Device`.
2. Enter the ColorBox IP or host.
3. Save the device.
4. Select it from the saved-device list.
5. Tap `Connect`.

If a ColorBox is advertising over Bonjour, it can also appear in the discovery list and be saved from there.

## Gang Control

TrackGrade now supports a first-pass gang workflow from the saved-device list.

1. Select the device you want to treat as the focus device.
2. In the saved-device list, tap the link icon on any peer devices you want to follow that focus device.
3. Work from the focused grading surface as usual.

The focused device remains the one shown on the right, but these actions are mirrored to linked peers:

- grade changes
- bypass
- false color, when supported
- preset recall

The grading header shows whether the linked peers are:

- synced
- waiting on connection/state
- drifted out of sync

## Main Grading Surface

The grading screen is a fixed landscape layout with no vertical scrolling.

### Top Bar

- device name and connection state
- bypass toggle
- controls drawer button
- settings button

### Center Surface

- compact device telemetry on the left
- live LGG / saturation state display in the center
- compact pipeline telemetry on the right
- saturation roller above the trackballs
- Lift, Gamma, and Gain trackball clusters below

### Reset Controls

Each grading region exposes clearly visible reset controls:

- `Reset All`
- per-cluster ball reset
- per-cluster ring reset
- saturation reset

By default, reset actions require a double-tap confirmation.

## Touch Controls

### Trackballs

Each Lift / Gamma / Gain cluster has:

- an inner ball for chroma movement
- an outer ring for luminance / overall-channel movement

The controls are relative, not spring-loaded. When you lift your finger, the value stays where you left it.

### Saturation Roller

The saturation control sits above the trackballs and adjusts the shared saturation value. It also uses relative movement.

### Numeric Editing

The live LGG/S state display is tappable so values can be nudged and inspected numerically.

## Drawer Panels

Tap `Controls` to open the slide-over drawer.

### Workflow

- Undo
- Redo
- Save Snapshot
- open the full snapshots browser
- A/B scratch slot store and recall
- placeholder library entry point

### Presets

- Save Preset
- Recall device-native presets
- Delete device-native presets

### Device

- pipeline actions and device-oriented secondary controls

## Presets Vs. Snapshots

TrackGrade has two different save concepts:

### Presets

- live on the ColorBox itself
- survive even if the iPad is gone
- are the correct tool for device-side show states

### Snapshots

- live only on the iPad
- are for quick local compare, show cues, and temporary workflow support
- include the current preview thumbnail when available

## Settings

The settings sheet currently exposes:

- per-control sensitivities
- haptics enable / disable
- reset-confirmation behavior
- an About section with version, license, repository, and conduct-contact details

## Offline Simulator Workflow

If you want to inspect the UI without a live ColorBox:

1. Open the `TrackGrade` scheme in Xcode.
2. Add the launch argument `-ui-test-fixture`.
3. Run on an iPad simulator.

That seeds a connected fixture device so you can walk through:

- grading UI
- bypass
- gang linking and gang broadcast
- presets
- snapshots
- settings

## Troubleshooting

### The app shows no discovered devices

- confirm the iPad and ColorBox are on the same subnet
- confirm Bonjour traffic is allowed on the network
- add the device manually by IP if needed

### The connection banner says retrying

- the app has lost network contact with the selected ColorBox
- TrackGrade will keep retrying automatically
- use the `Retry` button if you want to force an immediate reconnect

### False color is unavailable

The reference firmware used during development does not expose a working false-color API path. TrackGrade therefore treats false color as unsupported on that firmware instead of showing a dead toggle.

## Current Limitations

- The asset library browser is still limited.
- The current grading path writes directly through `/v2/pipelineStages` rather than uploading baked LUTs.
- Gang control currently focuses on mirroring a single focus device to linked peers; more advanced gang workflows can still be added later.
- Final tactile tuning still needs real iPad + ColorBox validation.
