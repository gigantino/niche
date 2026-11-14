import Foundation
import NowPlayingWire
import OSLog

@MainActor
final class NowPlayingMonitor: NowPlayingSource {
    var onChange: ((NowPlaying?) -> Void)?

    private var process: Process?
    private var commands: FileHandle?
    private var failures = 0
    private let log = Logger(subsystem: "ch.ggtn.niche", category: "media")

    private static let script = """
    use DynaLoader;
    my $library = DynaLoader::dl_load_file($ARGV[0], 0) or die DynaLoader::dl_error();
    my $entry = DynaLoader::dl_find_symbol($library, "niche_now_playing_run") or die "no entry point";
    DynaLoader::dl_install_xsub("main::run", $entry);
    main::run();
    """

    private static var library: URL? {
        let name = "libNicheNowPlaying.dylib"
        return [
            Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/\(name)"),
            Bundle.main.executableURL?.deletingLastPathComponent().appendingPathComponent(name)
        ]
        .compactMap { $0 }
        .first { FileManager.default.fileExists(atPath: $0.path) }
    }

    private static var artworkFolder: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ch.ggtn.niche/artwork", isDirectory: true)
    }

    func start() {
        signal(SIGPIPE, SIG_IGN)
        launch()
    }

    func send(_ command: NowPlaying.Command, position: Double?) {
        guard let data = try? JSONEncoder().encode(NowPlayingRequest(command: command, position: position)) else {
            return
        }
        try? commands?.write(contentsOf: data + Data("\n".utf8))
    }

    private func launch() {
        guard process == nil else { return }
        guard let library = Self.library else {
            log.error("the now playing library is missing")
            return
        }

        let process = Process()
        let output = Pipe()
        let input = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = ["-e", Self.script, library.path]
        process.environment = ProcessInfo.processInfo.environment
            .merging(["NICHE_ARTWORK": Self.artworkFolder.path]) { _, new in new }
        process.standardOutput = output
        process.standardInput = input
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            log.error("\(String(describing: error), privacy: .public)")
            return
        }
        self.process = process
        commands = input.fileHandleForWriting

        Task {
            let started = Date()
            do {
                for try await line in output.fileHandleForReading.bytes.lines {
                    receive(line)
                }
            } catch {}
            ended(after: Date().timeIntervalSince(started))
        }
    }

    private func receive(_ line: String) {
        do {
            onChange?(try JSONDecoder().decode(NowPlaying?.self, from: Data(line.utf8)))
        } catch {
            log.error("\(String(describing: error), privacy: .public)")
        }
    }

    private func ended(after lifetime: TimeInterval) {
        process = nil
        commands = nil
        onChange?(nil)

        failures = lifetime > 30 ? 0 : failures + 1
        let wait = min(2 * pow(2, Double(failures)), 120)
        log.notice("the now playing helper stopped, next start in \(wait, privacy: .public) s")
        Task {
            try? await Task.sleep(for: .seconds(wait))
            launch()
        }
    }
}
