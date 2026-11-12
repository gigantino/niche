import NicheKit
import SwiftUI

extension Animation {
    static func notch(stiffness: Double, damping: Double) -> Animation {
        .spring(response: 2 * .pi / stiffness.squareRoot(), dampingFraction: damping / (2 * stiffness.squareRoot()))
    }
}

extension ActivityCenter.Transition {
    var animation: Animation {
        switch self {
        case .appear: .notch(stiffness: 150, damping: 20)
        case .change: .easeOut(duration: 0.4)
        case .reconfigure: .easeOut(duration: 0.3)
        case .disappear: .notch(stiffness: 150, damping: 16)
        }
    }
}
