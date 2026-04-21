# TrackGrade

TrackGrade is an open-source native iPadOS 18+ control surface for live color grading with AJA ColorBox hardware over a local network. It is purpose-built for fast, touch-first Lift/Gamma/Gain adjustments during live IMAG workflows, with no cloud dependency and no intermediary server.

## Project Status

TrackGrade is in active early development. Phase 0 is focused on scaffolding, repository hygiene, a mock ColorBox server, and durable project documentation.

## Screenshots

Screenshots coming soon.

## Features

- Touch-based Lift, Gamma, and Gain trackball controls with luminance rings
- Saturation roller and live numeric state display
- Direct LAN communication with AJA ColorBox hardware
- Dynamic 3D LUT baking and upload workflow
- Device discovery, presets, snapshots, and multi-device gang support
- Mock ColorBox server for local development without hardware

## Requirements

- iPad running iPadOS 18.0 or later
- AJA ColorBox on the same IPv4 LAN/subnet for hardware testing
- Xcode 16 or later with Swift 6 support for development
- Bonjour/mDNS available on the local network

## Building

1. Open `TrackGrade.xcodeproj` in Xcode.
2. Select the `TrackGrade` scheme and an iPad simulator or device running iPadOS 18.0+.
3. Build and run the app target.

For package-based checks:

```sh
swift test
swift run MockColorBox
```

## Contributing

Contribution guidelines live in [CONTRIBUTING.md](CONTRIBUTING.md). Please also review [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) before opening issues or pull requests.

## License

TrackGrade is currently licensed under the MIT License. See [LICENSE](LICENSE).

## Disclaimer

TrackGrade is not affiliated with or endorsed by AJA Video Systems. AJA and ColorBox are trademarks of AJA Video Systems.
