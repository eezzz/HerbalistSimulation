import Foundation
import SwiftUI

struct Flags: Codable, Hashable {
    var late = false
    var first = false
    var crush = false
    var melt = false
    var honey = false
}

struct Item: Codable, Identifiable, Hashable {
    var id: String
    var g: Double
    var fl: Flags
}

struct Settings: Codable {
    var items: [Item] = []
    var method = "boil"          // "boil" 煮 / "infuse" 泡水
    var water: Double = 700
    var temp: Double = 95
    var minutes: Double = 30
    var soak = true
    var body = "平和"
    var preg = false
    var perDay = 1
    var days = 14
    var weight: Double = 60
    var lang: Lang = .zh
    var pn: String? = nil        // 当前载入的方名（中文键）
    var collapsed: [String: Bool] = [:]
}

enum AppTab: Hashable {
    case library, cabinet, formula, analysis
}

@MainActor
final class AppState: ObservableObject {
    @Published var s: Settings {
        didSet {
            Loc.lang = s.lang
            save()
        }
    }
    @Published var tab: AppTab = .library

    private static let key = "baicaoheng.state.v1"

    init() {
        if let raw = UserDefaults.standard.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode(Settings.self, from: raw) {
            var s = saved
            s.items = s.items.filter { DB.shared.byId[$0.id] != nil }
            self.s = s
        } else {
            var s = Settings()
            if Locale.preferredLanguages.first?.hasPrefix("zh") == false { s.lang = .en }
            self.s = s
            if let first = DB.shared.data.presets.first { applyPreset(first) }
        }
        Loc.lang = s.lang
    }

    var engine: Engine { Engine(S: s) }

    private func save() {
        if let raw = try? JSONEncoder().encode(s) { UserDefaults.standard.set(raw, forKey: Self.key) }
    }

    // MARK: 操作

    func applyPreset(_ p: Preset) {
        var n = s
        n.method = p.m
        n.water = p.w
        n.minutes = p.mi
        n.temp = p.t
        n.soak = p.soak
        n.items = p.items.compactMap { pi in
            guard let h = DB.shared.byId[pi.id] else { return nil }
            return Item(id: pi.id, g: pi.g, fl: defFlags(h))
        }
        n.pn = p.n
        s = n
    }

    func contains(_ id: String) -> Bool { s.items.contains { $0.id == id } }

    func toggleHerb(_ id: String) {
        if contains(id) { remove(id); return }
        guard let h = DB.shared.byId[id] else { return }
        var g = (h.mid * 2).rounded() / 2
        if g >= 6 { g = g.rounded() }
        var n = s
        n.items.append(Item(id: id, g: g, fl: defFlags(h)))
        n.pn = nil
        s = n
    }

    func remove(_ id: String) {
        var n = s
        n.items.removeAll { $0.id == id }
        n.pn = nil
        s = n
    }

    func clear() {
        var n = s
        n.items = []
        n.pn = nil
        s = n
    }

    func setGram(_ id: String, _ g: Double) {
        guard let i = s.items.firstIndex(where: { $0.id == id }) else { return }
        s.items[i].g = clamp(r1(g), 0, 120)
    }

    func step(_ id: String, _ delta: Double) {
        guard let i = s.items.firstIndex(where: { $0.id == id }) else { return }
        setGram(id, s.items[i].g + delta)
    }

    func toggleFlag(_ id: String, _ key: WritableKeyPath<Flags, Bool>) {
        guard let i = s.items.firstIndex(where: { $0.id == id }) else { return }
        s.items[i].fl[keyPath: key].toggle()
    }

    func setMethod(_ m: String) {
        guard s.method != m else { return }
        var n = s
        n.method = m
        if m == "infuse" {
            n.minutes = min(n.minutes, 12)
            n.temp = 95
            if n.water > 600 { n.water = 500 }
        } else {
            n.minutes = max(n.minutes, 20)
        }
        n.minutes = clamp(n.minutes, minuteRange(m).lowerBound, minuteRange(m).upperBound)
        s = n
    }

    func minuteRange(_ m: String? = nil) -> ClosedRange<Double> {
        (m ?? s.method) == "infuse" ? 2...40 : 5...90
    }

    func toggleLang() { s.lang = s.lang == .zh ? .en : .zh }

    func isCollapsed(_ key: String) -> Bool { s.collapsed[key] ?? false }

    func expandedBinding(_ key: String) -> Binding<Bool> {
        Binding(get: { !(self.s.collapsed[key] ?? false) },
                set: { self.s.collapsed[key] = !$0 })
    }

    func setAllCollapsed(_ keys: [String], _ collapsed: Bool) {
        var n = s
        for k in keys { n.collapsed[k] = collapsed }
        s = n
    }
}
