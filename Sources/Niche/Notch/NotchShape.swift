import SwiftUI

struct NotchShape: Shape {
    var earRadius: CGFloat
    var bottomRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(earRadius, bottomRadius) }
        set {
            earRadius = newValue.first
            bottomRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let ear = max(0, min(earRadius, rect.width / 4, rect.height / 2))
        let body = rect.insetBy(dx: ear, dy: 0)
        let bottom = max(0, min(bottomRadius, body.width / 2, body.height))
        let island = UnevenRoundedRectangle(
            bottomLeadingRadius: bottom,
            bottomTrailingRadius: bottom,
            style: .continuous
        )
        .path(in: body)
        guard ear > 0.01 else { return island }

        var ears = Path()
        for (outer, inner) in [(rect.minX, body.minX), (rect.maxX, body.maxX)] {
            ears.move(to: CGPoint(x: outer, y: rect.minY))
            ears.addArc(
                tangent1End: CGPoint(x: inner, y: rect.minY),
                tangent2End: CGPoint(x: inner, y: rect.minY + ear),
                radius: ear
            )
            ears.addLine(to: CGPoint(x: inner + (inner - outer) / 2, y: rect.minY + ear))
            ears.addLine(to: CGPoint(x: inner + (inner - outer) / 2, y: rect.minY))
            ears.closeSubpath()
        }
        return island.union(ears)
    }
}
