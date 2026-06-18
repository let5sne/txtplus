import AppKit

protocol TabBarDelegate: AnyObject {
    func tabBar(_ bar: TabBar, didSelect index: Int)
    func tabBar(_ bar: TabBar, didClose index: Int)
}

struct TabModel {
    var title: String
    var dirty: Bool
}

/// A single custom NSView that draws and hit-tests all tab cells.
final class TabBar: NSView {

    weak var delegate: TabBarDelegate?
    var tabs: [TabModel] = [] { didSet { needsDisplay = true; updateTracking() } }
    var selectedIndex: Int = 0 { didSet { needsDisplay = true } }

    private var hoveredIndex: Int? = nil
    private let cellHeight: CGFloat = 28
    private let minCellWidth: CGFloat = 90
    private let maxCellWidth: CGFloat = 220
    private let closeSize: CGFloat = 12

    override var isFlipped: Bool { true }

    init() {
        super.init(frame: .zero)
        wantsLayer = true
    }
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: cellHeight)
    }

    func cellRect(for index: Int) -> NSRect {
        let count = max(tabs.count, 1)
        let w = min(maxCellWidth, max(minCellWidth, bounds.width / CGFloat(count)))
        return NSRect(x: CGFloat(index) * w, y: 0, width: w, height: cellHeight)
    }

    private func closeRect(for index: Int) -> NSRect {
        let cell = cellRect(for: index)
        let s = closeSize
        return NSRect(x: cell.maxX - s - 8, y: (cell.height - s) / 2, width: s, height: s)
    }

    override func draw(_ dirtyRect: NSRect) {
        Theme.tabBarBg.setFill()
        NSBezierPath(rect: bounds).fill()
        for (i, tab) in tabs.enumerated() {
            let cell = cellRect(for: i)
            let active = i == selectedIndex
            let hovered = i == hoveredIndex
            if active {
                Theme.tabActiveBg.setFill()
                NSBezierPath(rect: cell).fill()
            } else if hovered {
                NSColor.underPageBackgroundColor.withAlphaComponent(0.3).setFill()
                NSBezierPath(rect: cell).fill()
            }
            // Title.
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12, weight: active ? .semibold : .regular),
                .foregroundColor: active ? NSColor.labelColor : NSColor.secondaryLabelColor
            ]
            let title = (tab.dirty ? "• " : "") + tab.title
            let titleStr = title as NSString
            let textSize = titleStr.size(withAttributes: attrs)
            let textX = cell.minX + 10
            let availWidth = closeRect(for: i).minX - textX - 4
            var drawTitle = title
            if textSize.width > availWidth {
                while drawTitle.count > 1 && (drawTitle as NSString).size(withAttributes: attrs).width > availWidth {
                    drawTitle = String(drawTitle.dropLast())
                }
                drawTitle += "…"
            }
            (drawTitle as NSString).draw(at: NSPoint(x: textX, y: (cellHeight - textSize.height) / 2), withAttributes: attrs)
            // Close × on active or hovered.
            if active || hovered {
                let cr = closeRect(for: i)
                let xColor = NSColor.secondaryLabelColor
                let path = NSBezierPath()
                path.move(to: NSPoint(x: cr.minX, y: cr.minY))
                path.line(to: NSPoint(x: cr.maxX, y: cr.maxY))
                path.move(to: NSPoint(x: cr.maxX, y: cr.minY))
                path.line(to: NSPoint(x: cr.minX, y: cr.maxY))
                xColor.setStroke()
                path.lineWidth = 1.4
                path.stroke()
            }
        }
        // Bottom hairline.
        NSColor.separatorColor.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: bounds.maxY - 1, width: bounds.width, height: 1)).fill()
    }

    private func hitTestCell(_ point: NSPoint) -> Int? {
        for i in 0..<tabs.count {
            if cellRect(for: i).contains(point) { return i }
        }
        return nil
    }

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        guard let i = hitTestCell(p) else { return }
        if closeRect(for: i).contains(p) {
            delegate?.tabBar(self, didClose: i)
        } else {
            delegate?.tabBar(self, didSelect: i)
        }
    }

    override func mouseMoved(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        let newHover = hitTestCell(p)
        if newHover != hoveredIndex {
            hoveredIndex = newHover
            needsDisplay = true
        }
    }

    override func mouseExited(with event: NSEvent) {
        if hoveredIndex != nil { hoveredIndex = nil; needsDisplay = true }
    }

    private func updateTracking() {
        let area = NSTrackingArea(rect: bounds, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(area)
    }
}
