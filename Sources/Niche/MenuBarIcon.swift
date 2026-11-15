import AppKit

enum MenuBarIcon {
    private static let canvas: CGFloat = 18
    private static let side: CGFloat = 15

    static var image: NSImage {
        let image = NSImage(size: NSSize(width: canvas, height: canvas), flipped: true) { _ in
            let scale = side / 824
            let origin = (canvas - side) / 2
            var transform = AffineTransform(translationByX: origin - 100 * scale, byY: origin - 100 * scale)
            transform.scale(scale)

            let square = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185)
            square.transform(using: transform)
            square.fill()

            let letter = NSBezierPath()
            letter.move(to: NSPoint(x: 352, y: 760))
            letter.line(to: NSPoint(x: 352, y: 480))
            letter.appendArc(withCenter: NSPoint(x: 512, y: 480), radius: 160, startAngle: 180, endAngle: 0, clockwise: false)
            letter.line(to: NSPoint(x: 672, y: 760))
            letter.transform(using: transform)
            letter.lineWidth = 118 * scale
            letter.lineCapStyle = .round
            NSGraphicsContext.current?.compositingOperation = .destinationOut
            letter.stroke()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Niche"
        return image
    }
}
