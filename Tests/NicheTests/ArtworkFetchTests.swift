import Foundation
import Testing
@testable import NicheNowPlaying

struct ArtworkFetchTests {
    let start = Date(timeIntervalSince1970: 1000)

    @Test func aNewItemWaitsForItsArtworkBeforeAnythingIsWritten() {
        var artwork = ArtworkFetch()

        #expect(artwork.step(key: "a", retry: true, now: start) == (.wait, true))
        #expect(artwork.step(key: "a", retry: true, now: start + 0.5) == (.wait, false))
        #expect(artwork.step(key: "a", retry: false, now: start + 5) == (.wait, false))
    }

    @Test func missingArtworkIsWrittenWithoutAndTriedAgainOnlyOnTheNextPoll() {
        var artwork = ArtworkFetch()
        _ = artwork.step(key: "a", retry: true, now: start)
        artwork.fetched(key: "a", path: nil)

        #expect(artwork.step(key: "a", retry: false, now: start) == (.withoutArtwork, false))
        #expect(artwork.step(key: "a", retry: true, now: start + 2) == (.withoutArtwork, true))
        #expect(artwork.step(key: "a", retry: true, now: start + 2.5) == (.withoutArtwork, false))
    }

    @Test func aFetchThatNeverAnswersDoesNotBlockTheNextItem() {
        var artwork = ArtworkFetch()
        _ = artwork.step(key: "a", retry: true, now: start)

        #expect(artwork.step(key: "b", retry: true, now: start + 1.1) == (.wait, true))
    }
}
