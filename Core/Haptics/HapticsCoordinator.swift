import Foundation

#if canImport(CoreHaptics) && canImport(UIKit)
import CoreHaptics
import UIKit

@MainActor
public final class HapticsCoordinator {
    public static let shared = HapticsCoordinator()

    private let centerImpactGenerator = UIImpactFeedbackGenerator(style: .light)
    private let buttonImpactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private var engine: CHHapticEngine?
    private var supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics

    public init() {
        centerImpactGenerator.prepare()
        buttonImpactGenerator.prepare()
        notificationGenerator.prepare()
        prepareEngineIfNeeded()
    }

    public func emitCenterTick(isEnabled: Bool) {
        guard isEnabled else {
            return
        }

        centerImpactGenerator.impactOccurred(intensity: 0.65)
        centerImpactGenerator.prepare()
    }

    public func emitButtonPress(isEnabled: Bool) {
        guard isEnabled else {
            return
        }

        buttonImpactGenerator.impactOccurred(intensity: 0.9)
        buttonImpactGenerator.prepare()
    }

    public func emitSuccess(isEnabled: Bool) {
        guard isEnabled else {
            return
        }

        notificationGenerator.notificationOccurred(.success)
        notificationGenerator.prepare()
    }

    public func emitDetent(isEnabled: Bool) {
        guard isEnabled else {
            return
        }

        guard supportsHaptics else {
            centerImpactGenerator.impactOccurred(intensity: 0.45)
            centerImpactGenerator.prepare()
            return
        }

        prepareEngineIfNeeded()

        let intensity = CHHapticEventParameter(
            parameterID: .hapticIntensity,
            value: 0.45
        )
        let sharpness = CHHapticEventParameter(
            parameterID: .hapticSharpness,
            value: 0.65
        )
        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [intensity, sharpness],
            relativeTime: 0
        )

        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine?.makePlayer(with: pattern)
            try engine?.start()
            try player?.start(atTime: 0)
        } catch {
            centerImpactGenerator.impactOccurred(intensity: 0.45)
            centerImpactGenerator.prepare()
        }
    }

    private func prepareEngineIfNeeded() {
        guard supportsHaptics, engine == nil else {
            return
        }

        do {
            engine = try CHHapticEngine()
            try engine?.start()
            engine?.stoppedHandler = { [weak self] _ in
                Task { @MainActor in
                    self?.engine = nil
                }
            }
        } catch {
            supportsHaptics = false
            engine = nil
        }
    }
}

#else

public struct HapticsCoordinator: Sendable {
    public static let shared = HapticsCoordinator()

    public init() {}

    public func emitCenterTick(isEnabled: Bool) {}
    public func emitButtonPress(isEnabled: Bool) {}
    public func emitSuccess(isEnabled: Bool) {}
    public func emitDetent(isEnabled: Bool) {}
}

#endif
