import AppKit
import ServiceManagement

/// The right-side menu bar icon and its menu: rename/recolor any Space, launch at login, quit.
final class StatusMenuController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let store: LabelStore
    private let readSpaces: () -> [DisplaySpaces]?

    /// The Space whose color the shared NSColorPanel is currently editing.
    private var colorPanelKey: String?

    init(store: LabelStore, readSpaces: @escaping () -> [DisplaySpaces]?) {
        self.store = store
        self.readSpaces = readSpaces
        super.init()
        statusItem.button?.image = NSImage(systemSymbolName: "tag", accessibilityDescription: "SpaceName")
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        guard let displays = readSpaces() else {
            menu.addItem(disabled("Space detection unavailable"))
            addFooter(to: menu)
            return
        }

        let active = displays.first { NSScreen.matching(displayIdentifier: $0.displayIdentifier) == NSScreen.main }
            ?? displays.first
        if let current = active?.current, !current.isFullScreen {
            menu.addItem(disabled("Current: \(store.displayName(for: current))"))
            menu.addItem(item("Rename This Space…", #selector(rename(_:)), key: current.key))
            menu.addItem(swatchItem(for: current.key))
            menu.addItem(item("Custom Color…", #selector(customColor(_:)), key: current.key))
        } else {
            menu.addItem(disabled("Full-screen Space"))
        }

        menu.addItem(.separator())
        let all = NSMenuItem(title: "All Spaces", action: nil, keyEquivalent: "")
        all.submenu = allSpacesMenu(displays)
        menu.addItem(all)

        addFooter(to: menu)
    }

    private func allSpacesMenu(_ displays: [DisplaySpaces]) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        for display in displays {
            if displays.count > 1 {
                let name = NSScreen.matching(displayIdentifier: display.displayIdentifier)?.localizedName ?? "Display"
                menu.addItem(disabled(name))
            }
            for space in display.spaces where !space.isFullScreen {
                let n = space.desktopNumber ?? 0
                let row = NSMenuItem(title: "\(n)   \(store.displayName(for: space))", action: nil, keyEquivalent: "")
                row.image = swatchImage(store.color(for: space))
                row.state = space == display.current ? .on : .off
                row.submenu = spaceMenu(for: space)
                menu.addItem(row)
            }
            if displays.count > 1 { menu.addItem(.separator()) }
        }
        return menu
    }

    private func spaceMenu(for space: Space) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.addItem(item("Rename…", #selector(rename(_:)), key: space.key))
        menu.addItem(swatchItem(for: space.key))
        menu.addItem(item("Custom Color…", #selector(customColor(_:)), key: space.key))
        menu.addItem(.separator())
        menu.addItem(item("Clear", #selector(clear(_:)), key: space.key))
        return menu
    }

    private func addFooter(to menu: NSMenu) {
        menu.addItem(.separator())
        let login = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        let quit = NSMenuItem(title: "Quit SpaceName", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    private func item(_ title: String, _ action: Selector, key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.representedObject = key
        return item
    }

    private func disabled(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func swatchItem(for key: String) -> NSMenuItem {
        let item = NSMenuItem()
        item.view = SwatchRowView { [weak self] hex in
            self?.store.setColor(NSColor(hex: hex), for: key)
        }
        return item
    }

    private func swatchImage(_ color: NSColor) -> NSImage {
        NSImage(size: NSSize(width: 12, height: 12), flipped: false) { rect in
            color.setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1)).fill()
            return true
        }
    }

    // MARK: Actions

    @objc private func rename(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        let alert = NSAlert()
        alert.messageText = "Rename Space"
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        field.stringValue = store.label(for: key).name ?? ""
        field.placeholderString = "Leave empty for the default"
        // Return in the field doesn't reach the alert's default button on its own.
        field.target = alert.buttons[0]
        field.action = #selector(NSButton.performClick(_:))
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            store.setName(field.stringValue, for: key)
        }
    }

    @objc private func customColor(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        colorPanelKey = key
        let panel = NSColorPanel.shared
        panel.showsAlpha = false
        panel.isContinuous = true
        panel.color = NSColor(hex: store.label(for: key).colorHex ?? LabelStore.defaultColorHex) ?? .gray
        panel.setTarget(self)
        panel.setAction(#selector(colorPanelChanged(_:)))
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    @objc private func colorPanelChanged(_ panel: NSColorPanel) {
        guard let key = colorPanelKey else { return }
        store.setColor(panel.color, for: key)
    }

    @objc private func clear(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        store.clear(key)
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("SpaceName: launch at login toggle failed: \(error)")
        }
    }
}

/// A menu row of clickable preset color circles. Hit-tests clicks itself:
/// NSButtons inside menu item views don't reliably receive clicks while the
/// menu is tracking.
private final class SwatchRowView: NSView {
    private let onPick: (String) -> Void
    private let size: CGFloat = 16
    private let gap: CGFloat = 6
    private let leading: CGFloat = 20

    init(onPick: @escaping (String) -> Void) {
        self.onPick = onPick
        let count = CGFloat(NSColor.presets.count)
        super.init(frame: NSRect(x: 0, y: 0, width: leading * 2 + count * size + (count - 1) * gap, height: 26))
    }

    required init?(coder: NSCoder) { fatalError() }

    private func swatchRect(_ i: Int) -> NSRect {
        NSRect(x: leading + CGFloat(i) * (size + gap), y: (bounds.height - size) / 2, width: size, height: size)
    }

    override func draw(_ dirtyRect: NSRect) {
        for (i, preset) in NSColor.presets.enumerated() {
            let circle = NSBezierPath(ovalIn: swatchRect(i).insetBy(dx: 1, dy: 1))
            (NSColor(hex: preset.hex) ?? .gray).setFill()
            circle.fill()
            NSColor.black.withAlphaComponent(0.15).setStroke()
            circle.stroke()
        }
    }

    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let i = NSColor.presets.indices.first(where: { swatchRect($0).insetBy(dx: -gap / 2, dy: -4).contains(point) }) else { return }
        onPick(NSColor.presets[i].hex)
        enclosingMenuItem?.menu?.cancelTracking()
    }
}
