import AppKit
import SwiftUI

struct AudioBarsNode: View {
    static let gap: CGFloat = 0.9

    let active: Bool
    let colors: [Color]

    @State private var listener: AudioMeter.Listener?

    var body: some View {
        let count = AudioBands.bands.count
        let palette = (0..<count).map { color($0, of: count) }

        TimelineView(.animation(paused: !active)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let heard = active ? AudioMeter.shared.levels : nil
            GeometryReader { proxy in
                let width = proxy.size.width / (CGFloat(count) + CGFloat(count - 1) * Self.gap)
                HStack(alignment: .center, spacing: width * Self.gap) {
                    ForEach(0..<count, id: \.self) { index in
                        Capsule()
                            .fill(palette[index])
                            .frame(
                                width: width,
                                height: max(width, proxy.size.height * level(index, at: time, heard: heard))
                            )
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .onAppear { listen(active) }
        .onChange(of: active) { _, active in listen(active) }
        .onDisappear { listener = nil }
    }

    private func listen(_ active: Bool) {
        listener = active ? listener ?? AudioMeter.shared.listen() : nil
    }

    private func level(_ index: Int, at time: Double, heard: [Float]?) -> CGFloat {
        guard active else { return 0 }
        if let heard, heard.indices.contains(index) { return CGFloat(heard[index]) }

        let speed = 5.5 + Double(index) * 1.7
        let phase = Double(index) * 1.3
        return 0.4 + 0.3 * sin(time * speed + phase)
    }

    private func color(_ index: Int, of count: Int) -> Color {
        guard let first = colors.first, let last = colors.last, colors.count > 1, count > 1,
              let start = NSColor(first).usingColorSpace(.sRGB),
              let end = NSColor(last).usingColorSpace(.sRGB),
              let mixed = start.blended(withFraction: CGFloat(index) / CGFloat(count - 1), of: end)
        else { return colors.first ?? .white }
        return Color(nsColor: mixed)
    }
}
