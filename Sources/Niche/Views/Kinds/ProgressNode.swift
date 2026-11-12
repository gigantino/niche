import NicheKit
import SwiftUI

struct ProgressNode: View {
    let node: Node
    let tint: Color

    var body: some View {
        if let interval = node.timerInterval, interval.count == 2, interval[0] < interval[1] {
            TimelineView(.periodic(from: .now, by: 0.25)) { timeline in
                let elapsed = (timeline.date.timeIntervalSince1970 - interval[0]) / (interval[1] - interval[0])
                gauge(node.countsDown == false ? elapsed : 1 - elapsed)
                    .animation(.linear(duration: 0.25), value: elapsed)
            }
        } else {
            gauge((node.value ?? 0) / max(node.total ?? 1, .leastNonzeroMagnitude))
        }
    }

    @ViewBuilder private func gauge(_ fraction: Double) -> some View {
        let fraction = min(max(fraction, 0), 1)

        if node.progressViewStyle == "circular" {
            let side = node.frame?.width ?? node.frame?.height ?? 20
            let lineWidth = max(2.5, side * 0.14)
            ZStack {
                Circle()
                    .stroke(tint.opacity(0.3), lineWidth: lineWidth)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .padding(lineWidth / 2)
            .frame(width: side, height: side)
        } else {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(white: 0.47, opacity: 0.36))
                    Capsule().fill(tint).frame(width: proxy.size.width * fraction)
                }
            }
            .frame(height: node.frame?.height ?? 4)
            .frame(minWidth: 24, idealWidth: 60)
        }
    }
}
