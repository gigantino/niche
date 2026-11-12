import SwiftUI

struct AudioBarsNode: View {
    let active: Bool
    let color: Color

    var body: some View {
        TimelineView(.animation(paused: !active)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            GeometryReader { proxy in
                HStack(alignment: .center, spacing: 2) {
                    ForEach(0..<5, id: \.self) { index in
                        Capsule()
                            .fill(color)
                            .frame(height: max(3, proxy.size.height * level(index, at: time)))
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
    }

    private func level(_ index: Int, at time: Double) -> CGFloat {
        guard active else { return 0.2 }
        let speed = 5.5 + Double(index) * 1.7
        let phase = Double(index) * 1.3
        return 0.55 + 0.45 * sin(time * speed + phase)
    }
}
