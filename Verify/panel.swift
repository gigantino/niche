import AppKit

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("panel: \(message)\n".utf8))
    exit(2)
}

func pixels(_ path: String) -> (data: [UInt8], width: Int, height: Int) {
    guard let image = NSImage(contentsOfFile: path)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        fail("cannot read \(path)")
    }
    var data = [UInt8](repeating: 0, count: image.width * image.height * 4)
    guard let context = CGContext(
        data: &data,
        width: image.width,
        height: image.height,
        bitsPerComponent: 8,
        bytesPerRow: image.width * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { fail("cannot decode \(path)") }
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    return (data, image.width, image.height)
}

let arguments = Array(CommandLine.arguments.dropFirst())

switch arguments.first {
case "window":
    let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
    for window in windows where window[kCGWindowOwnerName as String] as? String == "Niche" {
        let bounds = window[kCGWindowBounds as String] as? [String: CGFloat] ?? [:]
        if (bounds["Height"] ?? 0) > 100, let number = window[kCGWindowNumber as String] as? Int {
            print(number)
            exit(0)
        }
    }
    fail("the Niche panel is not on screen")

case "pointer":
    guard let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) else { fail("no screen has a notch") }
    let pointer = NSEvent.mouseLocation
    let near = abs(pointer.x - screen.frame.midX) < 300 && pointer.y > screen.frame.maxY - 290
    print(near ? "near" : "clear")

case "diff" where arguments.count == 3:
    let (first, second) = (pixels(arguments[1]), pixels(arguments[2]))
    guard first.width == second.width, first.height == second.height else {
        print("size \(first.width)x\(first.height) became \(second.width)x\(second.height)")
        exit(1)
    }
    var different = 0
    for index in stride(from: 0, to: first.data.count, by: 4) {
        let channels = (0..<4).map { abs(Int(first.data[index + $0]) - Int(second.data[index + $0])) }
        if channels.max() ?? 0 > 3 { different += 1 }
    }
    print(different)
    exit(different == 0 ? 0 : 1)

default:
    fail("usage: panel window | pointer | diff <a.png> <b.png>")
}
