import Foundation

func scalar(_ text: String) -> Any {
    if let number = Double(text) { return number }
    if text == "true" { return true }
    if text == "false" { return false }
    return text
}

func node(_ spec: String) -> [String: Any] {
    if spec.hasPrefix("{") || spec.hasPrefix("@") { return object(spec, what: "node") }

    var parts = spec.split(separator: ";", omittingEmptySubsequences: true).map(String.init)
    let head = parts.removeFirst().split(separator: ":", maxSplits: 1).map(String.init)
    let kind = head[0]
    let value = head.count > 1 ? head[1] : ""
    let now = Date().timeIntervalSince1970

    var result: [String: Any] = switch kind {
    case "text": ["type": "Text", "text": value]
    case "symbol": ["type": "Image", "systemName": value]
    case "image": ["type": "Image", "source": value]
    case "app": ["type": "Image", "app": value]
    case "progress": ["type": "ProgressView", "value": Double(value) ?? 0]
    case "ring": ["type": "ProgressView", "value": Double(value) ?? 0, "progressViewStyle": "circular"]
    case "timer": ["type": "Text", "timerInterval": [now, now + (Double(value) ?? 0)], "monospacedDigit": true]
    case "stopwatch": ["type": "Text", "date": now, "style": "timer", "monospacedDigit": true]
    case "bars": ["type": "AudioBars"]
    case "video": ["type": "Video", "source": value]
    case "web": ["type": "WebView", "source": value]
    default: fail("unknown node shorthand \"\(kind)\"")
    }

    for part in parts {
        let pair = part.split(separator: "=", maxSplits: 1).map(String.init)
        guard pair.count == 2 else { fail("expected key=value, got \"\(part)\"") }
        set(scalar(pair[1]), at: pair[0].split(separator: ".").map(String.init), in: &result)
    }
    return result
}
