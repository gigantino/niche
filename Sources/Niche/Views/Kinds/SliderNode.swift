import NicheKit
import SwiftUI

struct SliderNode: View {
    let node: Node
    let tint: Color
    let seek: (Double) -> Void

    @State private var dragged: Double?

    var body: some View {
        if let interval = node.timerInterval, interval.count == 2, interval[0] < interval[1] {
            let span = interval[1] - interval[0]
            TimelineView(.periodic(from: .now, by: 0.25)) { timeline in
                track((timeline.date.timeIntervalSince1970 - interval[0]) / span, span: span)
            }
        } else {
            let total = max(node.total ?? 1, .leastNonzeroMagnitude)
            track((node.value ?? 0) / total, span: total)
        }
    }

    private func track(_ fraction: Double, span: Double) -> some View {
        let shown = min(max(dragged ?? fraction, 0), 1)

        return GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(white: 0.47, opacity: 0.36))
                Capsule().fill(tint).frame(width: proxy.size.width * shown)
            }
            .frame(height: dragged == nil ? 6 : 9)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { dragged = min(max($0.location.x / proxy.size.width, 0), 1) }
                    .onEnded {
                        let fraction = min(max($0.location.x / proxy.size.width, 0), 1)
                        dragged = fraction
                        seek(fraction * span)
                        Task {
                            try? await Task.sleep(for: .seconds(1.5))
                            dragged = nil
                        }
                    }
            )
        }
        .frame(height: 18)
        .frame(minWidth: 40, idealWidth: 120)
        .animation(.easeOut(duration: 0.15), value: dragged == nil)
        .onChange(of: node) { dragged = nil }
    }
}
