import SwiftUI
import WebKit

struct WebNode: NSViewRepresentable {
    let source: String?
    let html: String?
    let send: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(context.coordinator, name: "niche")
        configuration.userContentController.addUserScript(WKUserScript(
            source: "window.niche = { send: action => webkit.messageHandlers.niche.postMessage(String(action)) }",
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))

        let view = WKWebView(frame: .zero, configuration: configuration)
        view.setValue(false, forKey: "drawsBackground")
        return view
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        context.coordinator.send = send
        guard context.coordinator.loaded != [source, html] else { return }
        context.coordinator.loaded = [source, html]

        if let html {
            view.loadHTMLString(html, baseURL: nil)
        } else if let source, source.hasPrefix("http"), let url = URL(string: source) {
            view.load(URLRequest(url: url))
        } else if let source {
            let url = URL(fileURLWithPath: (source as NSString).expandingTildeInPath)
            view.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        var send: (String) -> Void = { _ in }
        var loaded: [String?] = []

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            if let action = message.body as? String { send(action) }
        }
    }
}
