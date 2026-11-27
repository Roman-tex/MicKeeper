import AppKit

/// What the menu bar icon communicates. A filled microphone means MicKeeper is
/// holding the input; an outline means it is not. A slash is deliberately
/// avoided because it reads as "muted", which MicKeeper never does.
///
/// Every state is a monochrome template symbol: colour in the menu bar is
/// reserved for the system's recording indicator, and template images adapt
/// to light, dark and tinted menu bars.
enum StatusSymbol: Equatable {
    case holding, off, waiting, problem

    var name: String {
        switch self {
        case .holding: "microphone.fill"
        case .off: "microphone"
        case .waiting: "microphone.badge.ellipsis.fill"
        case .problem: "microphone.badge.xmark.fill"
        }
    }
}

/// Symbol image hosted inside the status item button. `NSButton` cannot run
/// symbol effects, so the button keeps the click handling and accessibility
/// while this view only draws and animates the glyph. Animations are one-shot
/// Core Animation effects: nothing runs while the icon is idle.
final class StatusIconView: NSImageView {
    private(set) var symbol: StatusSymbol?
    // Hierarchical rendering keeps the microphone secondary behind a badge,
    // so the waiting and error marks stay legible at menu bar size.
    private let configuration = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
        .applying(.preferringHierarchical())

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        imageScaling = .scaleNone
        setAccessibilityElement(false)
        translatesAutoresizingMaskIntoConstraints = false
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    // Clicks belong to the status item button underneath.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func show(_ next: StatusSymbol) {
        guard next != symbol, let image = NSImage(systemSymbolName: next.name, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration) else { return }
        image.isTemplate = true
        let previous = symbol
        symbol = next
        if previous == nil || reduceMotion {
            self.image = image
        } else {
            // Magic Replace morphs the shared microphone: the body fills when
            // holding starts, empties when it stops, and badges grow out of it.
            setSymbolImage(image, contentTransition: .replace.magic(fallback: .replace.downUp.byLayer))
        }
    }

    /// A single downward bounce when MicKeeper has just put the microphone back.
    func acknowledgeRestore() {
        guard symbol == .holding, !reduceMotion else { return }
        addSymbolEffect(.bounce.down.byLayer, options: .nonRepeating)
    }

    private var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
}
