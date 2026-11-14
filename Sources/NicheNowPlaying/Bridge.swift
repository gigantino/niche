import Foundation
import NowPlayingWire

@_cdecl("niche_now_playing_run")
public func nicheNowPlayingRun(_ interpreter: UnsafeRawPointer?, _ code: UnsafeRawPointer?) {
    let folder = ProcessInfo.processInfo.environment["NICHE_ARTWORK"] ?? NSTemporaryDirectory()
    MainActor.assumeIsolated {
        guard let remote = MediaRemote() else { exit(1) }
        let bridge = Bridge(remote: remote, artworkFolder: URL(fileURLWithPath: folder, isDirectory: true))
        Bridge.current = bridge
        bridge.start()
    }
    CFRunLoopRun()
}

@MainActor
final class Bridge {
    static var current: Bridge?

    private let remote: MediaRemote
    private let artworkFolder: URL
    private var emitted: NowPlaying?
    private var artwork = ArtworkFetch()
    private var scheduled = false

    init(remote: MediaRemote, artworkFolder: URL) {
        self.remote = remote
        self.artworkFolder = artworkFolder
    }

    func start() {
        try? FileManager.default.createDirectory(at: artworkFolder, withIntermediateDirectories: true)
        remote.register(.main)

        NotificationCenter.default.addObserver(forName: nil, object: nil, queue: .main) { [weak self] notification in
            guard notification.name.rawValue.contains("NowPlaying") else { return }
            MainActor.assumeIsolated { self?.schedule(after: 0.03) }
        }
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh(retry: true) }
        }
        Thread.detachNewThread {
            while let line = readLine() {
                DispatchQueue.main.async {
                    MainActor.assumeIsolated { Bridge.current?.perform(line) }
                }
            }
            exit(0)
        }
        refresh(retry: true)
    }

    private func schedule(after delay: TimeInterval) {
        guard !scheduled else { return }
        scheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            MainActor.assumeIsolated {
                self?.scheduled = false
                self?.refresh(retry: true)
            }
        }
    }

    private func refresh(retry: Bool) {
        let info = remote.info
        let nowPlaying = { (artwork: String?) in
            Snapshot.nowPlaying(
                info: info,
                bundleIdentifier: self.remote.bundleIdentifier,
                name: self.remote.name,
                pid: self.remote.pid,
                playing: self.remote.isPlaying,
                commands: self.remote.commands,
                artwork: artwork,
                now: Date()
            )
        }
        guard nowPlaying(nil) != nil else {
            emit(nil)
            return
        }

        let step = artwork.step(key: Snapshot.artworkKey(info), retry: retry, now: Date())
        switch step.write {
        case .wait: break
        case .withoutArtwork: emit(nowPlaying(nil))
        case .withArtwork(let path): emit(nowPlaying(path))
        }
        guard step.fetch else { return }

        remote.getInfo(.main) { [weak self] result in
            let result = result as? [String: Any] ?? [:]
            MainActor.assumeIsolated { self?.fetched(result) }
        }
    }

    private func fetched(_ info: [String: Any]) {
        let data = info[Snapshot.key("ArtworkData")] as? Data
        artwork.fetched(key: Snapshot.artworkKey(info), path: data.flatMap(store))
        refresh(retry: false)
    }

    private func store(_ data: Data) -> String? {
        let hash = data.reduce(into: UInt64(0xcbf29ce484222325)) { $0 = ($0 ^ UInt64($1)) &* 0x100000001b3 }
        let file = artworkFolder.appendingPathComponent(String(hash, radix: 16))
        if !FileManager.default.fileExists(atPath: file.path) {
            guard (try? data.write(to: file, options: .atomic)) != nil else { return nil }
            prune()
        }
        return file.path
    }

    private func prune() {
        let keys: Set<URLResourceKey> = [.contentModificationDateKey]
        let files = (try? FileManager.default.contentsOfDirectory(
            at: artworkFolder, includingPropertiesForKeys: Array(keys)
        )) ?? []
        let dated = files.map { ($0, (try? $0.resourceValues(forKeys: keys))?.contentModificationDate ?? .distantPast) }
        for (file, _) in dated.sorted(by: { $0.1 > $1.1 }).dropFirst(20) {
            try? FileManager.default.removeItem(at: file)
        }
    }

    private func emit(_ nowPlaying: NowPlaying?) {
        guard nowPlaying != emitted else { return }
        emitted = nowPlaying
        FileHandle.standardOutput.write(Data((Snapshot.line(nowPlaying) + "\n").utf8))
    }

    private func perform(_ line: String) {
        guard let request = try? JSONDecoder().decode(NowPlayingRequest.self, from: Data(line.utf8)) else { return }

        if let command = RemoteCommand(sending: request.command) {
            _ = remote.send(command.rawValue, nil)
        } else if let position = request.position {
            remote.setElapsed(position)
        } else {
            return
        }
        schedule(after: 0.2)
    }
}
