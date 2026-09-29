import AppKit

/// One click-through panel per display, floating over the center of its menu bar.
final class OverlayController {
    private var panels: [String: (panel: NSPanel, view: LabelView)] = [:]
    private let store: LabelStore

    /// Fraction of the screen width the label may occupy before truncating.
    private let maxWidthFraction: CGFloat = 0.4

    init(store: LabelStore) {
        self.store = store
    }

    /// Syncs panels to the current layout. Pass nil when Spaces can't be read.
    func update(with displays: [DisplaySpaces]?) {
        let displays = displays ?? []
        let wanted = Set(displays.map(\.displayIdentifier))
        for (id, entry) in panels where !wanted.contains(id) {
            entry.panel.orderOut(nil)
            panels[id] = nil
        }

        for display in displays {
            guard let screen = NSScreen.matching(displayIdentifier: display.displayIdentifier) else {
                panels[display.displayIdentifier]?.panel.orderOut(nil)
                continue
            }
            let entry = panels[display.displayIdentifier] ?? makePanel()
            panels[display.displayIdentifier] = entry
            layout(entry.panel, entry.view, on: screen)

            guard let space = display.current, !space.isFullScreen else {
                entry.panel.orderOut(nil)
                continue
            }

            let text = store.displayName(for: space)
            let color = store.color(for: space)
            entry.view.text = text
            entry.view.color = color
            entry.panel.orderFrontRegardless()
        }
    }

    private func makePanel() -> (panel: NSPanel, view: LabelView) {
        let panel = NSPanel(contentRect: .zero,
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered,
                            defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        // Just above the menu bar and its status items; below pop-up menus.
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]

        let view = LabelView(frame: .zero)
        panel.contentView = view
        return (panel, view)
    }

    private func layout(_ panel: NSPanel, _ view: LabelView, on screen: NSScreen) {
        let barHeight = screen.menuBarHeight
        let width = (screen.frame.width * maxWidthFraction).rounded()
        let frame = NSRect(x: screen.frame.midX - width / 2,
                           y: screen.frame.maxY - barHeight,
                           width: width,
                           height: barHeight)
        if panel.frame != frame { panel.setFrame(frame, display: false) }
        view.pillHeight = (barHeight * 0.75).rounded()
    }
}
