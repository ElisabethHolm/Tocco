import Foundation

extension InteractionMode {
    var clayName: String {
        switch self {
        case .sculpt: return "Shape"
        case .navigate: return "Move"
        }
    }

    var clayIcon: String {
        switch self {
        case .sculpt: return "hand.draw"
        case .navigate: return "arrow.up.and.down.and.arrow.left.and.right"
        }
    }

    var clayHint: String {
        switch self {
        case .sculpt:
            return "Pinch the ball to sculpt. Double-pinch in the air cycles Build → Carve → Blend. Blue = carved in, tan = surface, orange = built up."
        case .navigate:
            return "Touch and drag the arrows and rings on screen to move and turn the piece."
        }
    }
}

extension SculptTool {
    var clayName: String {
        switch self {
        case .push: return "Carve"
        case .pull: return "Build"
        case .smooth: return "Blend"
        }
    }

    var clayIcon: String {
        switch self {
        case .push: return "hand.point.up.left"
        case .pull: return "hand.pinch"
        case .smooth: return "hand.raised"
        }
    }
}
