import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = LabelStore()
    private lazy var overlay = OverlayController(store: store)
    private var statusMenu: StatusMenuController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusMenu = StatusMenuController(store: store, readSpaces: SpaceReader.read)
        store.onChange = { [weak self] in self?.refresh() }

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.refresh() }

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.refresh() }

        registerLoginItemOnFirstLaunch()
        refresh()
    }

    private func refresh() {
        overlay.update(with: SpaceReader.read())
    }

    private func registerLoginItemOnFirstLaunch() {
        let flag = "didSetUpLoginItem"
        guard !UserDefaults.standard.bool(forKey: flag) else { return }
        do {
            try SMAppService.mainApp.register()
            UserDefaults.standard.set(true, forKey: flag)
        } catch {
            NSLog("SpaceName: could not register login item: \(error)")
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
