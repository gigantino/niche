import Foundation

struct ArtworkFetch {
    enum Write: Equatable {
        case wait
        case withoutArtwork
        case withArtwork(String)
    }

    static let timeout: TimeInterval = 1
    static let attempts = 5

    private var found: (key: String, path: String)?
    private var misses: (key: String, count: Int) = ("", 0)
    private var fetch: (key: String, started: Date)?

    mutating func step(key: String, retry: Bool, now: Date) -> (write: Write, fetch: Bool) {
        if let found, found.key == key {
            return (.withArtwork(found.path), false)
        }
        if let fetch, retry, now.timeIntervalSince(fetch.started) > Self.timeout {
            miss(fetch.key)
            self.fetch = nil
        }

        let missed = misses.key == key && misses.count > 0
        if missed, !retry || misses.count >= Self.attempts {
            return (.withoutArtwork, false)
        }
        guard fetch == nil else { return (missed ? .withoutArtwork : .wait, false) }

        fetch = (key, now)
        return (missed ? .withoutArtwork : .wait, true)
    }

    mutating func fetched(key: String, path: String?) {
        fetch = nil
        if let path {
            found = (key, path)
        } else {
            miss(key)
        }
    }

    private mutating func miss(_ key: String) {
        misses = (key, misses.key == key ? misses.count + 1 : 1)
    }
}
