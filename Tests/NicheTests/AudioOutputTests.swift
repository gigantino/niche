import Darwin
import Testing
@testable import Niche

struct AudioOutputTests {
    @Test func aPlayerPlaysHereWhenItOrOneOfItsProcessesSendsSound() {
        let owners: [pid_t: pid_t] = [10: 10, 11: 10, 20: 20]
        let responsible = { (pid: pid_t) in owners[pid] ?? pid }
        func plays(_ pid: pid_t, _ bundle: String, _ playing: [(pid: pid_t, bundleIdentifier: String)]) -> Bool {
            AudioOutput.plays(pid: pid, bundleIdentifier: bundle, among: playing, responsible: responsible)
        }

        #expect(plays(10, "com.spotify.client", [(10, "com.spotify.client")]))
        #expect(plays(10, "com.google.Chrome", [(30, "com.google.Chrome.helper")]))
        #expect(plays(10, "com.apple.Safari", [(11, "com.apple.WebKit.GPU")]))
        #expect(!plays(10, "com.spotify.client", [(20, "com.apple.Music")]))
        #expect(!plays(0, "com.spotify.client", [(0, "")]))
    }
}
