import AppKit

final class StatusBar: NSView {

    private let leftField = NSTextField(labelWithString: "")
    private let rightField = NSTextField(labelWithString: "")

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        leftField.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        leftField.textColor = .secondaryLabelColor
        rightField.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        rightField.textColor = .secondaryLabelColor
        rightField.alignment = .right
        for f in [leftField, rightField] {
            f.translatesAutoresizingMaskIntoConstraints = false
            addSubview(f)
        }
        NSLayoutConstraint.activate([
            leftField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            leftField.centerYAnchor.constraint(equalTo: centerYAnchor),
            rightField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            rightField.centerYAnchor.constraint(equalTo: centerYAnchor),
            heightAnchor.constraint(equalToConstant: 22),
        ])
    }
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func update(line: Int, column: Int, language: String, chars: Int, selection: Int) {
        leftField.stringValue = "\(language)   ·   \(chars) chars"
        rightField.stringValue = "Ln \(line), Col \(column)" + (selection > 0 ? "   ·   \(selection) selected" : "")
    }

    override func draw(_ dirtyRect: NSRect) {
        Theme.statusBg.setFill()
        NSBezierPath(rect: bounds).fill()
        NSColor.separatorColor.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: bounds.width, height: 1)).fill()
    }
}
