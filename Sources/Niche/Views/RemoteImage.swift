import AppKit
import SwiftUI

@MainActor
enum ImageCache {
    private static let store = NSCache<NSString, NSImage>()

    static func cached(_ url: URL) -> NSImage? {
        store.object(forKey: url.absoluteString as NSString)
    }

    static func file(_ url: URL) -> NSImage? {
        let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        let key = "\(url.path)\n\(modified?.timeIntervalSince1970 ?? 0)" as NSString
        if let image = store.object(forKey: key) { return image }
        guard let data = try? Data(contentsOf: url), let image = NSImage(data: data) else { return nil }
        store.setObject(image, forKey: key)
        return image
    }

    static func load(_ url: URL) async -> NSImage? {
        if let image = cached(url) { return image }
        guard let (data, _) = try? await URLSession.shared.data(from: url), let image = NSImage(data: data) else {
            return nil
        }
        store.setObject(image, forKey: url.absoluteString as NSString)
        return image
    }
}

struct RemoteImage: View {
    let url: URL
    let mode: ContentMode

    @State private var loaded: NSImage?

    var body: some View {
        ZStack {
            if let image = ImageCache.cached(url) ?? loaded {
                Image(nsImage: image).resizable().aspectRatio(contentMode: mode)
            } else {
                Color.white.opacity(0.08)
            }
        }
        .task(id: url) {
            if let image = await ImageCache.load(url) { loaded = image }
        }
    }
}
