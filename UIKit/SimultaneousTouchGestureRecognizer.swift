import UIKit

enum SimultaneousTouchInputKind: Equatable {
    case direct
    case pencil
}

enum SimultaneousTouchEvent: Equatable {
    case began(start: CGPoint, inputKind: SimultaneousTouchInputKind)
    case changed(
        start: CGPoint,
        location: CGPoint,
        translation: CGSize,
        inputKind: SimultaneousTouchInputKind
    )
    case ended(
        start: CGPoint,
        location: CGPoint,
        translation: CGSize,
        inputKind: SimultaneousTouchInputKind
    )
    case cancelled(inputKind: SimultaneousTouchInputKind)
}

final class SimultaneousTouchGestureRecognizer: UIGestureRecognizer, UIGestureRecognizerDelegate {
    var eventHandler: ((SimultaneousTouchEvent) -> Void)?

    private weak var trackedTouch: UITouch?
    private var startLocation: CGPoint = .zero
    private var currentLocation: CGPoint = .zero

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        delegate = self
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
        requiresExclusiveTouchType = false
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard trackedTouch == nil,
              let touch = touches.first(where: isSupportedTouch) else {
            return
        }

        trackedTouch = touch
        startLocation = touch.location(in: view)
        currentLocation = startLocation
        state = .began
        eventHandler?(.began(start: startLocation, inputKind: inputKind(for: touch)))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let trackedTouch,
              touches.contains(trackedTouch) else {
            return
        }

        currentLocation = trackedTouch.location(in: view)
        state = .changed
        eventHandler?(
            .changed(
                start: startLocation,
                location: currentLocation,
                translation: translation,
                inputKind: inputKind(for: trackedTouch)
            )
        )
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let trackedTouch,
              touches.contains(trackedTouch) else {
            return
        }

        currentLocation = trackedTouch.location(in: view)
        state = .ended
        eventHandler?(
            .ended(
                start: startLocation,
                location: currentLocation,
                translation: translation,
                inputKind: inputKind(for: trackedTouch)
            )
        )
        self.trackedTouch = nil
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let trackedTouch,
              touches.contains(trackedTouch) else {
            return
        }

        state = .cancelled
        eventHandler?(.cancelled(inputKind: inputKind(for: trackedTouch)))
        self.trackedTouch = nil
    }

    override func reset() {
        trackedTouch = nil
        startLocation = .zero
        currentLocation = .zero
    }

    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool {
        false
    }

    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool {
        false
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }

    private var translation: CGSize {
        CGSize(
            width: currentLocation.x - startLocation.x,
            height: currentLocation.y - startLocation.y
        )
    }

    private func isSupportedTouch(_ touch: UITouch) -> Bool {
        switch touch.type {
        case .direct, .pencil:
            return true
        default:
            return false
        }
    }

    private func inputKind(for touch: UITouch) -> SimultaneousTouchInputKind {
        touch.type == .pencil ? .pencil : .direct
    }
}
