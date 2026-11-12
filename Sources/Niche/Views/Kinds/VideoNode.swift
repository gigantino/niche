import AVFoundation
import SwiftUI

struct VideoNode: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> PlayerView {
        PlayerView(url: url)
    }

    func updateNSView(_ view: PlayerView, context: Context) {}

    final class PlayerView: NSView {
        private let player = AVQueuePlayer()
        private let looper: AVPlayerLooper

        init(url: URL) {
            looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
            super.init(frame: .zero)

            player.isMuted = true
            player.allowsExternalPlayback = false
            player.preventsDisplaySleepDuringVideoPlayback = false

            let layer = AVPlayerLayer(player: player)
            layer.videoGravity = .resizeAspect
            layer.backgroundColor = .black
            self.layer = layer
            wantsLayer = true
            player.play()
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError()
        }
    }
}
