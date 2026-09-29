import AppKit

struct Space: Equatable {
    /// Stable identity for labels. The Space UUID, or a per-display fallback for
    /// the original desktop, which macOS reports with an empty UUID.
    let key: String
    /// "Desktop N" number, matching Mission Control. Nil for full-screen Spaces.
    let desktopNumber: Int?

    var isFullScreen: Bool { desktopNumber == nil }
}

struct DisplaySpaces: Equatable {
    /// CGS display identifier: a display UUID string, or "Main" when
    /// "Displays have separate Spaces" is off.
    let displayIdentifier: String
    let current: Space?
    let spaces: [Space]
}

enum SpaceReader {
    private static let desktopType = 0

    /// Returns nil if the private API returns nothing usable (e.g. changed by an OS update).
    static func read() -> [DisplaySpaces]? {
        guard let raw = CGSCopyManagedDisplaySpaces(CGSMainConnectionID()) as? [[String: Any]],
              !raw.isEmpty else { return nil }

        var result: [DisplaySpaces] = []
        for display in raw {
            guard let displayID = display["Display Identifier"] as? String,
                  let rawSpaces = display["Spaces"] as? [[String: Any]] else { return nil }

            var spaces: [Space] = []
            var desktopCount = 0
            var byManagedID: [Int: Space] = [:]
            for s in rawSpaces {
                let type = s["type"] as? Int ?? desktopType
                var number: Int?
                if type == desktopType {
                    desktopCount += 1
                    number = desktopCount
                }
                let space = Space(key: key(for: s, displayID: displayID), desktopNumber: number)
                spaces.append(space)
                if let id = s["ManagedSpaceID"] as? Int { byManagedID[id] = space }
            }

            var current: Space?
            if let cur = display["Current Space"] as? [String: Any],
               let id = cur["ManagedSpaceID"] as? Int {
                current = byManagedID[id]
            }
            result.append(DisplaySpaces(displayIdentifier: displayID, current: current, spaces: spaces))
        }
        return result
    }

    private static func key(for space: [String: Any], displayID: String) -> String {
        if let uuid = space["uuid"] as? String, !uuid.isEmpty { return uuid }
        return "default:\(displayID)"
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }

    var displayUUID: String? {
        guard let id = displayID,
              let uuid = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue() else { return nil }
        return CFUUIDCreateString(nil, uuid) as String
    }

    /// The screen a CGS display identifier refers to.
    static func matching(displayIdentifier: String) -> NSScreen? {
        if displayIdentifier == "Main" { return NSScreen.screens.first }
        return NSScreen.screens.first { $0.displayUUID?.caseInsensitiveCompare(displayIdentifier) == .orderedSame }
    }

    var menuBarHeight: CGFloat {
        let h = frame.maxY - visibleFrame.maxY
        return h > 0 ? h : NSStatusBar.system.thickness
    }
}
