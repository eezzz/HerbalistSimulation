import Foundation

/// 按症状找方：与网页版 symMatch() 同一算法。
/// 每个方子先按其自身煮法算出功效构成，再与所选症状对应的功效加权匹配。
struct SymptomHit: Identifiable {
    let p: Preset
    let score: Double
    let hit: [Symptom]
    let tags: [(String, Double)]
    let preg: Bool
    var id: String { p.n }
}

enum SymptomFlag {
    case crisis, medical
}

enum SymptomSearch {
    private struct Profile {
        let tagN: OrderedSum
        let preg: Bool
    }

    private static var cache: [String: Profile] = [:]

    private static func profile(_ p: Preset) -> Profile {
        if let hit = cache[p.n] { return hit }
        var s = Settings()
        s.method = p.m
        s.water = p.w
        s.minutes = p.mi
        s.temp = p.t
        s.soak = p.soak
        s.items = p.items.compactMap { pi in
            guard let h = DB.shared.byId[pi.id] else { return nil }
            return Item(id: pi.id, g: pi.g, fl: defFlags(h))
        }
        let c = Engine(S: s).compute()
        let pr = Profile(tagN: c.tagN, preg: c.rows.contains { $0.h.preg > 0 })
        cache[p.n] = pr
        return pr
    }

    static func text(_ x: Symptom) -> String { L(x.k, x.en) }

    /// 从输入文字中识别症状（中英同义词，双向包含）
    static func fromQuery(_ query: String) -> [Symptom] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }
        return DB.shared.data.symptoms.filter { x in
            ([x.k, x.en] + x.syn).contains { raw in
                let w = raw.lowercased()
                return q.contains(w) || (q.count >= 2 && w.contains(q))
            }
        }
    }

    static func flag(_ query: String) -> SymptomFlag? {
        let q = query.lowercased()
        if DB.shared.data.crisis.contains(where: { q.contains($0.lowercased()) }) { return .crisis }
        if DB.shared.data.redFlags.contains(where: { q.contains($0.lowercased()) }) { return .medical }
        return nil
    }

    static func match(query: String, selected: Set<String>) -> (active: [Symptom], results: [SymptomHit]) {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let ql = q.lowercased()
        var active: [Symptom] = DB.shared.data.symptoms.filter { selected.contains($0.k) }
        for x in fromQuery(q) where !active.contains(x) { active.append(x) }

        var res: [SymptomHit] = []
        for p in DB.shared.data.presets where p.c != "配伍反例" {
            let pr = profile(p)
            var score = 0.0
            var hit: [Symptom] = []
            for x in active {
                let m = x.tags.reduce(0) { $0 + $1.v * pr.tagN[$1.k] }
                score += m
                if m >= 0.08 { hit.append(x) }
            }
            if !active.isEmpty { score /= Double(active.count) }
            let nameHit = ql.count >= 2 && (pName(p).lowercased().contains(ql) || pDesc(p).lowercased().contains(ql) || p.n.contains(q))
            if nameHit { score += 0.15 }
            if score < 0.08 && !nameHit { continue }
            var seen = Set<String>()
            var tagKeys: [String] = []
            for x in active { for kv in x.tags where !seen.contains(kv.k) { seen.insert(kv.k); tagKeys.append(kv.k) } }
            let tags = tagKeys.map { ($0, pr.tagN[$0]) }.filter { $0.1 > 0.03 }.sorted { $0.1 > $1.1 }.prefix(3)
            res.append(SymptomHit(p: p, score: score, hit: hit, tags: Array(tags), preg: pr.preg))
        }
        let sorted = res.enumerated().sorted { $0.element.score != $1.element.score ? $0.element.score > $1.element.score : $0.offset < $1.offset }.map { $0.element }
        return (active, Array(sorted.prefix(12)))
    }
}
