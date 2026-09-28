import AppKit

@MainActor
enum StatusIcon {
    private static let badgeGap: CGFloat = 2

    // Speed line rows in the StatusIcon SVG's 20x18 viewBox. Keep in sync if the SVG is redrawn.
    private static let viewBoxWidth: CGFloat = 20
    private static let speedLineRows: [CGFloat] = [7.75, 10.75]
    private static let speedLineThickness: CGFloat = 1.4
    /// During a meeting the speed lines grow to this length and the clock moves right to make room.
    private static let progressLineLength: CGFloat = 7.5
    private static let clockShift: CGFloat = 4
    private static let trackAlpha: CGFloat = 0.3

    /// A template image: the named asset, or during a meeting the clock with its speed lines drawn as progress bars,
    /// plus an optional overlap badge.
    static func image(named name: String, progress: Double?, overlap: Bool) -> NSImage? {
        let base: NSImage? = progress.flatMap(clockWithProgressLines) ?? NSImage(named: name)
        guard let base else { return nil }
        let badge = overlap ? NSImage(systemSymbolName: "square.on.square", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 9, weight: .semibold)) : nil

        let width = base.size.width + (badge.map { badgeGap + $0.size.width } ?? 0)
        let height = max(base.size.height, badge?.size.height ?? 0)
        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { _ in
            base.draw(in: NSRect(x: 0, y: (height - base.size.height) / 2, width: base.size.width, height: base.size.height))
            if let badge {
                let origin = NSPoint(x: base.size.width + badgeGap, y: (height - badge.size.height) / 2)
                badge.draw(in: NSRect(origin: origin, size: badge.size))
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    /// The top line fills during the first half of the meeting, the bottom line during the second.
    private static func clockWithProgressLines(_ progress: Double) -> NSImage? {
        guard let glyph = NSImage(named: "StatusIconNoLines") else { return nil }
        let scale = glyph.size.width / viewBoxWidth
        let thickness = speedLineThickness * scale
        let size = NSSize(width: glyph.size.width + clockShift, height: glyph.size.height)
        let elapsed = min(max(progress, 0), 1)

        return NSImage(size: size, flipped: false) { _ in
            glyph.draw(in: NSRect(x: clockShift, y: 0, width: glyph.size.width, height: glyph.size.height))
            for (index, row) in speedLineRows.enumerated() {
                let track = NSRect(x: 0, y: size.height - row * scale - thickness / 2, width: progressLineLength, height: thickness)
                let fill = min(max(elapsed * 2 - Double(index), 0), 1)
                capsule(track, alpha: trackAlpha)
                capsule(NSRect(x: track.minX, y: track.minY, width: max(thickness, track.width * fill), height: thickness), alpha: 1)
            }
            return true
        }
    }

    private static func capsule(_ rect: NSRect, alpha: CGFloat) {
        NSColor.black.withAlphaComponent(alpha).setFill()
        let radius = min(rect.width, rect.height) / 2
        NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
    }
}
