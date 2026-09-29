import AppKit

struct SpaceLabel: Equatable {
    var name: String?
    var colorHex: String?
}

/// Space key → label, persisted in UserDefaults under "labels" as
/// { key: { name: String, color: "#RRGGBB" } }.
final class LabelStore {
    static let defaultColorHex = "#8E8E93"
    private let defaultsKey = "labels"
    private let defaults = UserDefaults.standard

    var onChange: (() -> Void)?

    func label(for key: String) -> SpaceLabel {
        let dict = all()[key] ?? [:]
        return SpaceLabel(name: dict["name"], colorHex: dict["color"])
    }

    func displayName(for space: Space) -> String {
        if let name = label(for: space.key).name, !name.isEmpty { return name }
        return "Desktop \(space.desktopNumber ?? 0)"
    }

    func color(for space: Space) -> NSColor {
        NSColor(hex: label(for: space.key).colorHex ?? Self.defaultColorHex) ?? .gray
    }

    func setName(_ name: String?, for key: String) {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        update(key) { $0["name"] = (trimmed?.isEmpty ?? true) ? nil : trimmed }
    }

    func setColor(_ color: NSColor?, for key: String) {
        update(key) { $0["color"] = color?.hexString }
    }

    func clear(_ key: String) {
        var labels = all()
        labels[key] = nil
        save(labels)
    }

    private func update(_ key: String, _ body: (inout [String: String]) -> Void) {
        var labels = all()
        var entry = labels[key] ?? [:]
        body(&entry)
        labels[key] = entry.isEmpty ? nil : entry
        save(labels)
    }

    private func all() -> [String: [String: String]] {
        defaults.dictionary(forKey: defaultsKey) as? [String: [String: String]] ?? [:]
    }

    private func save(_ labels: [String: [String: String]]) {
        defaults.set(labels, forKey: defaultsKey)
        onChange?()
    }
}
