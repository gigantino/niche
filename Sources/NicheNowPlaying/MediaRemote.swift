import Foundation
import NowPlayingWire

enum RemoteCommand: UInt32 {
    case play = 0
    case pause = 1
    case togglePlayPause = 2
    case nextTrack = 4
    case previousTrack = 5
    case seekToPlaybackPosition = 24

    init?(sending command: NowPlaying.Command) {
        switch command {
        case .playPause: self = .togglePlayPause
        case .next: self = .nextTrack
        case .previous: self = .previousTrack
        case .seek: return nil
        }
    }

    var command: NowPlaying.Command {
        switch self {
        case .play, .pause, .togglePlayPause: .playPause
        case .nextTrack: .next
        case .previousTrack: .previous
        case .seekToPlaybackPosition: .seek
        }
    }
}

struct MediaRemote {
    typealias Register = @convention(c) (DispatchQueue) -> Void
    typealias GetInfo = @convention(c) (DispatchQueue, @escaping @convention(block) (CFDictionary?) -> Void) -> Void
    typealias Send = @convention(c) (UInt32, CFDictionary?) -> Bool
    typealias SetElapsed = @convention(c) (Double) -> Void

    let register: Register
    let getInfo: GetInfo
    let send: Send
    let setElapsed: SetElapsed
    let request: NSObject

    init?() {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW),
              let register = dlsym(handle, "MRMediaRemoteRegisterForNowPlayingNotifications"),
              let getInfo = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo"),
              let send = dlsym(handle, "MRMediaRemoteSendCommand"),
              let setElapsed = dlsym(handle, "MRMediaRemoteSetElapsedTime"),
              let request = NSClassFromString("MRNowPlayingRequest") as AnyObject as? NSObject
        else { return nil }

        self.register = unsafeBitCast(register, to: Register.self)
        self.getInfo = unsafeBitCast(getInfo, to: GetInfo.self)
        self.send = unsafeBitCast(send, to: Send.self)
        self.setElapsed = unsafeBitCast(setElapsed, to: SetElapsed.self)
        self.request = request
    }

    var client: NSObject? {
        Self.value(Self.value(request, "localNowPlayingPlayerPath"), "client") as? NSObject
    }

    var bundleIdentifier: String? {
        let parent = Self.value(client, "parentApplicationBundleIdentifier") as? String
        return parent.flatMap { $0.isEmpty ? nil : $0 } ?? Self.value(client, "bundleIdentifier") as? String
    }

    var name: String? {
        Self.value(client, "displayName") as? String
    }

    var pid: Int {
        (Self.value(client, "processIdentifier") as? NSNumber)?.intValue ?? 0
    }

    var isPlaying: Bool {
        (Self.value(request, "localIsPlaying") as? NSNumber)?.boolValue ?? false
    }

    var info: [String: Any] {
        Self.value(Self.value(request, "localNowPlayingItem"), "nowPlayingInfo") as? [String: Any] ?? [:]
    }

    var commands: [Int] {
        (Self.value(request, "localSupportedCommands") as? [NSObject] ?? []).compactMap { command in
            guard (Self.value(command, "enabled") as? NSNumber)?.boolValue == true else { return nil }
            return (Self.value(command, "command") as? NSNumber)?.intValue
        }
    }

    private static func value(_ object: Any?, _ key: String) -> Any? {
        let getters = [key, "is" + key.prefix(1).uppercased() + key.dropFirst()]
        guard let object = object as? NSObject,
              getters.contains(where: { object.responds(to: NSSelectorFromString($0)) })
        else { return nil }
        return object.value(forKey: key)
    }
}
