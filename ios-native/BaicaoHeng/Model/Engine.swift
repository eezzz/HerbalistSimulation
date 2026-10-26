import Foundation

// 计算模型：与网页版 index.html 中的 compute / dosing / buildAlerts 等函数逐项对应。

let EL = ["木", "火", "土", "金", "水"]
let FL5 = ["酸", "苦", "甘", "辛", "咸"]
let FL2EL: [String: String] = ["酸": "木", "涩": "木", "苦": "火", "甘": "土", "淡": "土", "辛": "金", "咸": "水"]
let MER2EL: [String: String] = ["肝": "木", "胆": "木", "心": "火", "小肠": "火", "心包": "火", "三焦": "火",
                                "脾": "土", "胃": "土", "肺": "金", "大肠": "金", "肾": "水", "膀胱": "水"]
let SHENG: [String: String] = ["木": "火", "火": "土", "土": "金", "金": "水", "水": "木"]
let KE: [String: String] = ["木": "土", "土": "水", "水": "火", "火": "金", "金": "木"]

/// 保持插入顺序的累加表（排序时同值按先出现者在前，与网页版一致）
struct OrderedSum {
    private(set) var keys: [String] = []
    private(set) var vals: [String: Double] = [:]

    mutating func add(_ k: String, _ v: Double) {
        if vals[k] == nil { keys.append(k); vals[k] = 0 }
        vals[k]! += v
    }
    subscript(_ k: String) -> Double { vals[k] ?? 0 }
    var total: Double {
        let t = vals.values.reduce(0, +)
        return t == 0 ? 1 : t
    }
    func normalized() -> OrderedSum {
        var o = self
        let t = total
        for k in keys { o.vals[k] = (vals[k] ?? 0) / t }
        return o
    }
    func sortedDesc() -> [(String, Double)] {
        let indexed = keys.enumerated().map { ($0.offset, $0.element, vals[$0.element] ?? 0) }
        return indexed.sorted { $0.2 != $1.2 ? $0.2 > $1.2 : $0.0 < $1.0 }.map { ($0.1, $0.2) }
    }
}

struct Cfg {
    var method: String
    var minutes: Double
    var temp: Double
    var soak: Bool
    var R: Double
}

struct Row: Identifiable {
    let it: Item
    let h: Herb
    let g: Double
    let e: Double      // 单次溶出率
    let rel: Double    // 相对标准制法
    let et: Double     // 当日合计（含复煎/续泡）
    let s: Double      // 药力
    let ex: Double
    var id: String { h.id }
}

struct Calc {
    var rows: [Row] = []
    var S0 = 1.0
    var G = 0.0
    var T = 0.0
    var fl = OrderedSum()
    var el = OrderedSum()
    var mer = OrderedSum()
    var tagN = OrderedSum()
    var ni = 0.0
    var exTotal = 0.0
    var out = 0
    var evap = 0.0
    var conc = 0.0
}

enum Level: Int {
    case red = 0, amber, info, ok
}

struct AlertItem: Identifiable {
    let id = UUID()
    let lv: Level
    let ty: String
    let t: String
}

struct Intake: Identifiable {
    let id = UUID()
    let k: String
    let v: Double
    let lim: Double
    var lim2: Double? = nil
    let u: String
    var perDose = false
    let n: String
}

struct LongTerm {
    let days: Int
    let reason: String
}

struct DRow: Identifiable {
    let r: Row
    let daily: Double
    let total: Double
    let lt: LongTerm?
    var id: String { r.h.id }
}

struct Dosing {
    let rows: [DRow]
    let I: [Intake]
    let dailyTotal: Double
    let courseTotal: Double
    let maxDays: Int
    let binding: [String]
    let rest: Int
    let A: [AlertItem]
}

struct BodyFit {
    let score: Int?
    let lab: String
    let notes: [String]
    let bad: Bool
}

struct ComboHit: Identifiable {
    let id: String
    let name: String
    let text: String
    let ratioLine: String?
    let ratioOK: Bool
}

func defFlags(_ h: Herb) -> Flags {
    Flags(late: h.has("late"), first: h.has("first"), crush: h.has("crush"), melt: h.has("melt"), honey: h.has("honey"))
}

func matchCombo(_ x: Combo, _ ids: Set<String>) -> Bool {
    x.need.allSatisfy { alts in alts.contains { ids.contains($0) } }
}

func natLabel(_ T: Double) -> String {
    if T <= -1.6 { return "寒" }
    if T <= -0.6 { return "凉" }
    if T <= -0.2 { return "微凉" }
    if T < 0.2 { return "平" }
    if T < 0.6 { return "微温" }
    if T < 1.6 { return "温" }
    return "热"
}

struct Engine {
    let S: Settings
    private var db: DB { DB.shared }

    // MARK: 溶出

    /// 单次溶出率：该次煎/泡中有效成分转移到汤液的比例；R = 加水量 ÷ 药量
    func extraction(_ h: Herb, _ fl: Flags, _ c: Cfg) -> Double {
        let P = db.part(h.p)
        if h.has("melt") { return fl.melt ? 0.95 : (c.method == "boil" ? 0.4 : 0.1) }
        if h.p == "sugar" { return 0.98 }
        var e: Double
        if c.method == "infuse" {
            let tf = clamp(0.72 + (c.temp - 80) * 0.014, 0.6, 1)
            let tconst = h.ti > 0 ? h.ti : P.ti
            let time = 1 - exp(-c.minutes / tconst)
            e = P.E * (h.infK > 0 ? h.infK : P.inf) * tf * time
            if h.has("crush") { e *= fl.crush ? 1.3 : 0.8 }
        } else {
            var mins = c.minutes
            var loss = 1.0
            var tb = P.tb
            if h.has("late") {
                if fl.late { mins = min(mins, 5); tb = 3 } else { loss = exp(-max(0, mins - 8) / 20) }
            }
            if h.has("first") && fl.first { mins += 30 }
            e = P.E * (1 - exp(-mins / tb)) * loss
            let hard = ["root", "bark", "stem", "fungus", "seed", "bulb", "slice"]
            if !c.soak && hard.contains(h.p) { e *= 0.88 }
            if h.has("crush") && !fl.crush { e *= 0.75 }
        }
        e *= clamp(pow(c.R / 10, 0.25), 0.7, 1.08)
        return clamp(e, 0, 0.95)
    }

    func curRatio() -> Double {
        let G = S.items.reduce(0) { $0 + $1.g }
        return G > 0 ? S.water / G : 10
    }

    func cfgNow() -> Cfg { Cfg(method: S.method, minutes: S.minutes, temp: S.temp, soak: S.soak, R: curRatio()) }

    /// 标准制法下的参照溶出率（药典常用量按规范汤剂；西方浸泡类药材按沸水加盖泡 10 分钟）
    func eRef(_ h: Herb) -> Double {
        let cfg = h.std == "infuse"
            ? Cfg(method: "infuse", minutes: 10, temp: 100, soak: true, R: 30)
            : Cfg(method: "boil", minutes: 30, temp: 100, soak: true, R: 10)
        return extraction(h, defFlags(h), cfg)
    }

    /// 当日累计：煮 = 头煎 + 复煎；泡 = 首泡 + 续泡
    func eTotal(_ e: Double) -> Double {
        max(e, clamp(e + (1 - e) * e * (S.method == "boil" ? 0.7 : 0.6), 0, 0.97))
    }

    // MARK: 主计算

    func compute() -> Calc {
        var c = Calc()
        let cfg = cfgNow()
        c.rows = S.items.compactMap { it -> Row? in
            guard let h = db.byId[it.id], it.g > 0 else { return nil }
            let e = extraction(h, it.fl, cfg)
            let ref = eRef(h)
            let rel = ref > 0 ? e / ref : 1
            return Row(it: it, h: h, g: it.g, e: e, rel: rel, et: eTotal(e), s: it.g / h.mid * min(rel, 1.2), ex: it.g * e)
        }
        let s0 = c.rows.reduce(0) { $0 + $1.s }
        c.S0 = s0 == 0 ? 1 : s0
        c.G = c.rows.reduce(0) { $0 + $1.g }
        c.T = c.rows.reduce(0) { $0 + $1.s * $1.h.t } / c.S0

        var fl = OrderedSum(); FL5.forEach { fl.add($0, 0) }
        var el = OrderedSum(); EL.forEach { el.add($0, 0) }
        var mer = OrderedSum()
        var tags = OrderedSum()
        var ni = 0.0
        for r in c.rows {
            let fs: [String] = r.h.f.map { ch in
                let s = String(ch)
                return s == "涩" ? "酸" : (s == "淡" ? "甘" : s)
            }
            let nf = Double(max(fs.count, 1))
            for f in fs {
                fl.add(f, r.s / nf)
                el.add(FL2EL[f] ?? "土", 0.5 * r.s / nf)
            }
            let nm = Double(max(r.h.mer.count, 1))
            for m in r.h.mer {
                mer.add(m, r.s / nm)
                el.add(MER2EL[m] ?? "土", 0.5 * r.s / nm)
            }
            if r.h.t > 0 { el.add("火", r.s * r.h.t * 0.06) }
            if r.h.t < 0 { el.add("水", r.s * -r.h.t * 0.06) }
            for kv in r.h.fx { tags.add(kv.k, kv.v * r.s) }
            ni += r.h.ni * r.s
        }
        c.fl = fl.normalized()
        c.el = el.normalized()
        c.mer = mer.normalized()
        c.tagN = tags.normalized()
        c.ni = ni / c.S0
        c.exTotal = c.rows.reduce(0) { $0 + $1.ex }
        var out: Double
        if S.method == "infuse" {
            out = S.water - c.G * 1.2
        } else {
            let first = c.rows.contains { $0.h.has("first") && $0.it.fl.first }
            c.evap = S.minutes * 2.5 + (first ? 30 * 2.5 : 0)
            out = S.water - c.evap - c.G * 2.5
        }
        c.out = Int(max(0, out).rounded())
        c.conc = c.out > 0 ? c.exTotal / Double(c.out) * 100 : 99
        return c
    }

    func topTags(_ c: Calc, _ n: Int = 4) -> [(String, Double)] {
        Array(c.tagN.sortedDesc().filter { $0.0 != "调和" }.prefix(n))
    }

    // MARK: 君臣佐使

    func roleMap(_ c: Calc) -> [String: String] {
        var map: [String: String] = [:]
        let rs = c.rows.enumerated()
            .sorted { $0.element.s != $1.element.s ? $0.element.s > $1.element.s : $0.offset < $1.offset }
            .map { $0.element }
        guard !rs.isEmpty else { return map }
        var jun = rs[0]
        if jun.h.fxValue("调和") >= 3 && rs.count > 1 { jun = rs[1] }
        let ids = Set(rs.map { $0.h.id })
        if let cb = db.data.combos.first(where: { !$0.jun.isEmpty && matchCombo($0, ids) }),
           let j = rs.first(where: { cb.jun.contains($0.h.id) }) {
            jun = j
        }
        map[jun.h.id] = "君"
        let jt = jun.h.fx.enumerated()
            .sorted { $0.element.v != $1.element.v ? $0.element.v > $1.element.v : $0.offset < $1.offset }
            .prefix(3).map { $0.element.k }.filter { $0 != "调和" }
        let hasJiang = rs.contains { $0.h.id == "shengjiang" }
        let hasZao = rs.contains { $0.h.id == "dazao" }
        for r in rs where r.h.id != jun.h.id {
            let isEnvoy = r.h.fxValue("调和") >= 3
                || (r.h.id == "dazao" && hasJiang)
                || (r.h.id == "shengjiang" && hasZao && jun.h.id != "shengjiang")
            if isEnvoy {
                map[r.h.id] = "使"
            } else if r.h.fx.contains(where: { jt.contains($0.k) && $0.v >= 2 }) {
                map[r.h.id] = "臣"
            } else {
                map[r.h.id] = "佐"
            }
        }
        return map
    }

    // MARK: 体重

    /// 低体重（<50 kg）时按经验收紧常用量上限，只影响提醒
    func wf() -> Double { S.weight < 50 ? clamp(S.weight / 55, 0.7, 1) : 1 }
    func upper(_ h: Herb) -> Double { max(h.dMin, (h.dMax * wf() * 2).rounded() / 2) }

    func weightHint() -> (text: String, idle: Bool) {
        let names: [String: (String, String)] = [
            "rougui": ("香豆素上限", "coumarin limit"),
            "chaye": ("咖啡因上限", "caffeine limit"),
            "gancao": ("甘草酸保守参考值", "conservative glycyrrhizin value"),
        ]
        let hit: [String] = S.items.compactMap { i in
            guard let w = names[i.id], i.g > 0, let h = db.byId[i.id] else { return nil }
            return hnShort(h) + L("的", "’s ") + L(w.0, w.1)
        }
        let low = S.weight < 50
        var parts: [String] = []
        if !hit.isEmpty { parts.append(L("影响：", "Affects: ") + joinList(hit)) }
        if low {
            let p = Int((wf() * 100).rounded())
            parts.append(L("低于 50 kg：超量提醒阈值收紧为常用上限的 \(p)%", "Under 50 kg: overdose alerts tightened to \(p)% of the usual maximum"))
        }
        if parts.isEmpty {
            parts.append(L("当前方中没有按体重计算的成分（肉桂、绿茶、甘草）；低于 50 kg 时会收紧剂量提醒",
                           "No weight-based compounds in this formula (cinnamon, green tea, licorice); below 50 kg dose alerts are tightened"))
        }
        return (parts.joined(separator: "\n"), hit.isEmpty && !low)
    }

    // MARK: 每日总量与疗程

    func dosing(_ c: Calc) -> Dosing {
        let pd = Double(S.perDay)
        let days = S.days
        let W = S.weight
        let rows: [DRow] = c.rows.map { r in
            let daily = r.g * pd
            var lt: LongTerm? = nil
            if let e = db.data.lt[r.h.id] { lt = LongTerm(days: e.days, reason: L(e.zh, e.en)) }
            if r.h.id == "gancao" {
                if daily > 6 {
                    lt = LongTerm(days: 14, reason: L("甘草酸累积致假性醛固酮增多（低钾、水肿、高血压）", db.data.ltGancao.hi))
                } else if daily > 3 {
                    lt = LongTerm(days: 28, reason: L("甘草酸累积致假性醛固酮增多", db.data.ltGancao.mid))
                } else {
                    lt = nil
                }
            }
            if lt == nil && r.h.t <= -2 {
                lt = LongTerm(days: 21, reason: L("性寒，久服伤脾胃阳气", "cold in nature; prolonged use damages spleen–stomach yang"))
            }
            return DRow(r: r, daily: daily, total: daily * Double(days), lt: lt)
        }
        let dailyTotal = rows.reduce(0) { $0 + $1.daily }

        // 关键成分每日摄入估算（含量 × 溶出率）
        var I: [Intake] = []
        func f(_ id: String) -> DRow? { rows.first { $0.r.h.id == id } }
        if let gc = f("gancao") {
            let v2 = r1(0.2 * W)
            I.append(Intake(k: L("甘草酸", "Glycyrrhizin"), v: gc.daily * 30 * gc.r.et, lim: 100, lim2: 0.2 * W, u: "mg",
                            n: L("按含量约 3% 估算。实线：欧盟 SCF 建议长期摄入 ≤ 100 mg/日；橙线：按体重的保守参考值 0.2 mg/kg·日（\(num(W)) kg → \(num(v2)) mg，van Gelderen 2000）",
                                 "Assumes ~3% content. Solid line: EU SCF limit of 100 mg/day for regular intake; orange line: conservative weight-based value of 0.2 mg/kg/day (\(num(W)) kg → \(num(v2)) mg; van Gelderen 2000)")))
        }
        if let rg = f("rougui") {
            I.append(Intake(k: L("香豆素", "Coumarin"), v: rg.daily * 4 * rg.r.et, lim: 0.1 * W, u: "mg",
                            n: L("中国肉桂约 0.4% 估算；EFSA 可耐受摄入 0.1 mg/kg·日（按 \(num(W)) kg）",
                                 "Assumes ~0.4% in cassia; EFSA tolerable intake 0.1 mg/kg/day (at \(num(W)) kg)")))
        }
        if let ch = f("chaye") {
            let limDay: Double = S.preg ? 200 : 400
            I.append(Intake(k: L("咖啡因", "Caffeine"), v: ch.daily * 30 * ch.r.et, lim: limDay, u: "mg",
                            n: L("绿茶约 3% 估算；成人每日上限 \(S.preg ? "200（孕期）" : "400") mg，另需计入咖啡、可乐",
                                 "Assumes ~3% in green tea; adult daily limit \(S.preg ? "200 (pregnancy)" : "400") mg — count coffee and cola too")))
            I.append(Intake(k: L("咖啡因（单剂）", "Caffeine (per dose)"), v: ch.r.g * 30 * ch.r.et, lim: 3 * W, u: "mg", perDose: true,
                            n: L("EFSA：单次约 3 mg/kg 以内不引起健康担忧（\(num(W)) kg → \(num(3 * W)) mg），按一剂一次喝完计",
                                 "EFSA: single doses up to about 3 mg/kg raise no safety concern (\(num(W)) kg → \(num(3 * W)) mg), assuming one dose is drunk at once")))
        }
        let SUG: [String: Double] = ["hongtang": 0.95, "bingtang": 1, "fengmi": 0.8, "longyan": 0.65, "dazao": 0.6]
        let sug = rows.filter { SUG[$0.r.h.id] != nil }
        if !sug.isEmpty {
            let v = sug.reduce(0) { $0 + $1.daily * (SUG[$1.r.h.id] ?? 0) * $1.r.et }
            I.append(Intake(k: L("糖", "Sugar"), v: v, lim: 25, u: "g",
                            n: L("红糖、冰糖、蜂蜜、龙眼肉、大枣中溶入汤液的糖；WHO 建议游离糖最好 < 25 g/日",
                                 "Sugar dissolved from brown sugar, rock sugar, honey, longan and jujube; WHO suggests free sugars ideally < 25 g/day")))
        }

        // 建议最长连服天数
        var lim: [(Int, String)] = []
        let aT = abs(c.T)
        let nat = natLabel(c.T)
        let natEn = natT(nat).lowercased()
        if aT > 0.6 {
            lim.append((aT > 1.2 ? 14 : 28, L("全方药性\(nat)，偏性\(aT > 1.2 ? "明显" : "较明显")",
                                              "formula is \(natEn), a \(aT > 1.2 ? "strong" : "noticeable") bias")))
        } else {
            lim.append((56, L("全方药性平和", "formula is mild in nature")))
        }
        if c.ni > 0.6 { lim.append((28, L("滋腻药比重大，久服碍胃", "many rich, cloying tonics; prolonged use burdens digestion"))) }
        for x in rows { if let lt = x.lt { lim.append((lt.days, hnShort(x.r.h) + COLON() + lt.reason)) } }
        for x in I where x.v > x.lim && !x.perDose {
            lim.append((7, L("\(x.k)每日摄入超过参考上限", "daily \(x.k.lowercased()) exceeds the reference limit")))
        }
        let maxDays = lim.map { $0.0 }.min() ?? 56
        let binding = lim.filter { $0.0 == maxDays }.map { $0.1 }
        let rest = max(3, Int((Double(maxDays) / 4).rounded()))

        var A: [AlertItem] = []
        if days > maxDays {
            A.append(AlertItem(lv: days > maxDays * 2 ? .red : .amber, ty: L("疗程过长", "Course too long"),
                               t: L("计划连服 \(days) 天，超过建议的 \(maxDays) 天。限制因素：\(binding.joined(separator: "；"))。",
                                    "You plan \(days) days in a row, beyond the suggested \(maxDays). Limiting factor: \(binding.joined(separator: "; ")).")))
        }
        let capDay: Double = S.method == "infuse" ? 60 : 150
        if dailyTotal > capDay {
            A.append(AlertItem(lv: .amber, ty: L("每日总量偏大", "High daily total"),
                               t: L("每日总药量 \(num(dailyTotal)) g，超过\(S.method == "infuse" ? "代茶饮" : "保健汤剂")一般上限约 \(num(capDay)) g。",
                                    "Daily total \(num(dailyTotal)) g exceeds the usual ceiling of about \(num(capDay)) g for a \(S.method == "infuse" ? "herbal tea" : "wellness decoction").")))
        }
        for x in I where x.v > x.lim {
            let long = days > 14 && !x.perDose
            let zh = "估算\(x.perDose ? "每剂" : "每日") \(num(x.v)) \(x.u)，超过参考上限 \(num(x.lim)) \(x.u)\(x.perDose ? "，可分次饮用" : "")\(long ? "，连服 \(days) 天累积风险较高" : "")。"
            // 三种情况各写整句，便于翻译时按句式匹配
            let en = x.perDose
                ? "Estimated \(num(x.v)) \(x.u) per dose (split it into smaller servings), above the reference limit of \(num(x.lim)) \(x.u)."
                : (long
                    ? "Estimated \(num(x.v)) \(x.u)/day, above the reference limit of \(num(x.lim)) \(x.u); over \(days) days the cumulative risk is higher."
                    : "Estimated \(num(x.v)) \(x.u)/day, above the reference limit of \(num(x.lim)) \(x.u).")
            A.append(AlertItem(lv: days > 14 ? .red : .amber, ty: L("\(x.k)超量", "\(x.k) over limit"), t: L(zh, en)))
        }
        return Dosing(rows: rows, I: I, dailyTotal: dailyTotal, courseTotal: dailyTotal * Double(days),
                      maxDays: maxDays, binding: binding, rest: rest, A: A)
    }

    // MARK: 注意事项

    func alerts(_ c: Calc, _ d: Dosing) -> [AlertItem] {
        var A = d.A
        let ids = Set(c.rows.map { $0.h.id })
        for x in db.data.conflicts where ids.contains(x.a) && ids.contains(x.b) {
            guard let ha = db.byId[x.a], let hb = db.byId[x.b] else { continue }
            let e = db.data.en.conflicts["\(x.a)|\(x.b)"]
            let lv: Level = x.lv == "red" ? .red : (x.lv == "amber" ? .amber : .info)
            A.append(AlertItem(lv: lv, ty: L(x.ty, e?.ty ?? x.ty), t: "\(hnShort(ha)) × \(hnShort(hb))" + COLON() + L(x.t, e?.t ?? x.t)))
        }
        if S.preg {
            for r in c.rows {
                if r.h.preg == 2 {
                    A.append(AlertItem(lv: .red, ty: L("孕期禁用", "Avoid in pregnancy"), t: hnShort(r.h) + COLON() + hw(r.h)))
                } else if r.h.preg == 1 {
                    A.append(AlertItem(lv: .amber, ty: L("孕期慎用", "Caution in pregnancy"),
                                       t: L("\(r.h.n)：孕期须在医师指导下使用。", "\(hnShort(r.h)): use in pregnancy only under medical supervision.")))
                }
            }
        }
        for r in c.rows {
            let h = r.h
            let n = hnShort(h)
            let daily = r1(r.g * Double(S.perDay))
            let pdTxt = S.perDay > 1
                ? L("每剂 \(num(r.g)) g × \(S.perDay) 剂 = 每日 \(num(daily)) g", "\(num(r.g)) g × \(S.perDay) doses = \(num(daily)) g/day")
                : L("每日 \(num(daily)) g", "\(num(daily)) g/day")
            let U = upper(h)
            let UT = U < h.dMax ? L("（体重 \(num(S.weight)) kg，按 \(num(U)) g 计）", " (at \(num(S.weight)) kg, using \(num(U)) g)") : ""
            let range = "\(num(h.dMin))–\(num(h.dMax))"
            if daily > U * 2 {
                A.append(AlertItem(lv: .red, ty: L("日量过大", "Daily dose too high"),
                                   t: L("\(n) \(pdTxt)，超过常用日量上限 \(num(h.dMax)) g 的两倍\(UT)。",
                                        "\(n) \(pdTxt) — more than twice the usual daily maximum of \(num(h.dMax)) g\(UT).")))
            } else if daily > U {
                A.append(AlertItem(lv: .amber, ty: L("超日常用量", "Above usual dose"),
                                   t: L("\(n) \(pdTxt)，高于常用日量 \(range) g\(UT)。", "\(n) \(pdTxt) — above the usual daily range of \(range) g\(UT).")))
            } else if daily < h.dMin * 0.5 {
                A.append(AlertItem(lv: .info, ty: L("量偏小", "Low dose"),
                                   t: L("\(n) \(pdTxt)，低于常用量下限一半，作用轻微。", "\(n) \(pdTxt) — under half the usual minimum; effect will be slight.")))
            }
            if S.method == "infuse" && r.rel < 0.4 {
                let inf = h.std == "infuse"
                let ep = Int((r.e * 100).rounded()), rp = Int((r.rel * 100).rounded())
                let zh = "\(n)（\(db.part(h.p).lab)）泡水估算溶出 \(ep)%，只相当于标准\(inf ? "泡法" : "煎煮")的 \(rp)%。建议\(inf ? "用沸水、加盖、延长焖泡" : "切薄片、延长焖泡，或改用煮")。"
                let en = "\(n) (\(partN(h.p))) extracts ~\(ep)% when steeped — only \(rp)% of a standard \(inf ? "infusion. Use boiling water, cover, and steep longer" : "decoction. Slice thinly, steep longer, or decoct instead")."
                A.append(AlertItem(lv: .info, ty: L("溶出偏低", "Poor extraction"), t: L(zh, en)))
            }
            if S.method == "boil" && h.has("late") && !r.it.fl.late && S.minutes > 10 {
                A.append(AlertItem(lv: .info, ty: L("宜后下", "Add last"),
                                   t: L("\(n)含挥发性成分，久煎 \(num(S.minutes)) 分钟损失明显，建议关火前 5 分钟放入。",
                                        "\(n) contains volatile oils that are largely lost over \(num(S.minutes)) minutes. Add it in the last 5 minutes.")))
            }
            if S.method == "boil" && h.has("first") && !r.it.fl.first {
                A.append(AlertItem(lv: .info, ty: L("宜先煎", "Cook first"),
                                   t: L("\(n)质地坚硬，宜先煎 30 分钟再下其他药。", "\(n) is hard; simmer it 30 minutes before adding the other herbs.")))
            }
            if h.has("crush") && !r.it.fl.crush {
                let zao = h.id == "dazao"
                A.append(AlertItem(lv: .info, ty: zao ? L("宜掰开", "Split open") : L("宜捣碎", "Crush first"),
                                   t: L("\(n)\(zao ? "整枚" : "完整")使用时有效成分难以溶出。", "Used whole, \(n) releases little of its active content.")))
            }
            if h.has("separate") {
                A.append(AlertItem(lv: .info, ty: L("另煎", "Simmer separately"),
                                   t: L("\(n)贵重，宜单独小火另煎 1–2 小时后兑入，或切薄片含服/泡服。",
                                        "\(n) is costly; simmer it alone on low heat for 1–2 hours and add the liquid, or hold thin slices in the mouth / steep them.")))
            }
            if h.tox > 0 {
                if S.method == "infuse" {
                    A.append(AlertItem(lv: .red, ty: L("不宜泡水", "Do not steep"),
                                       t: L("\(n)含苦杏仁苷，泡水无法经高温破坏其毒性成分，须煎煮使用。",
                                            "\(n) contains amygdalin. Steeping does not destroy its toxic component; it must be boiled.")))
                }
                if r.g > U {
                    A.append(AlertItem(lv: .red, ty: L("有毒药超量", "Toxic herb overdose"),
                                       t: L("\(n)有小毒，\(num(r.g)) g 超过常用上限 \(num(h.dMax)) g，过量可致氰化物中毒。",
                                            "\(n) is mildly toxic. \(num(r.g)) g exceeds the usual maximum of \(num(h.dMax)) g; overdose can cause cyanide poisoning.")))
                }
            }
            if h.has("powder") {
                let t = h.id == "jineijin"
                    ? L("鸡内金研末吞服（每次 1.5–3 g）效果优于入汤剂，其消化酶不耐高温。",
                        "Chicken gizzard lining works better swallowed as powder (1.5–3 g per dose); its enzymes do not survive boiling.")
                    : L("\(n)研粉吞服（每次 1–3 g）效果为佳，入汤剂效力降低。", "\(n) works best swallowed as powder (1–3 g per dose); decocting weakens it.")
                A.append(AlertItem(lv: .info, ty: L("研粉", "Take as powder"), t: t))
            }
            if h.has("melt") && !r.it.fl.melt {
                let boil = S.method == "boil"
                let zh = "\(n)与群药同\(boil ? "煎易粘锅、包裹他药" : "泡难以溶化")。应隔水蒸化或用热药液溶化后兑服。"
                let en = boil
                    ? "Cooked with the other herbs, \(n) sticks to the pot and coats them. Melt it over a water bath or in the hot strained liquid, then stir in."
                    : "\(n) will not dissolve by steeping. Melt it over a water bath or in the hot strained liquid, then stir in."
                A.append(AlertItem(lv: .amber, ty: L("宜烊化", "Melt separately"), t: L(zh, en)))
            }
            if h.has("honey") && !r.it.fl.honey {
                A.append(AlertItem(lv: .info, ty: L("蜂蜜宜温调", "Add honey warm"),
                                   t: L("蜂蜜不宜久煮或沸水冲，待汤液降至 60 °C 以下再调入，以保留酶类、减少 5-羟甲基糠醛生成。",
                                        "Do not boil honey or add it to boiling water. Stir it in once the liquid is below 60 °C to keep its enzymes and limit HMF formation.")))
            }
            if h.formLv == 2 {
                A.append(AlertItem(lv: .amber, ty: L("须用炮制品", "Use the processed form"), t: hform(h)))
            } else if h.formLv == 1 {
                A.append(AlertItem(lv: .info, ty: L("规格", "Form"), t: hform(h)))
            }
            if !h.warn.isEmpty {
                A.append(AlertItem(lv: .red, ty: L("药物相互作用", "Drug interactions"), t: n + COLON() + hwarn(h)))
            }
            if h.raw > 0 && S.method == "infuse" {
                let eb = h.id == "elderberry"
                A.append(AlertItem(lv: .red, ty: L("必须煮熟", "Must be cooked"),
                                   t: L("\(n)生品含\(eb ? "生氰苷与" : "")植物凝集素，泡水不能使其失活，可致恶心呕吐，须充分煮熟。",
                                        "Raw \(n) contains \(eb ? "cyanogenic glycosides and " : "")lectins that steeping cannot deactivate; it can cause nausea and vomiting. Boil thoroughly.")))
            }
        }
        if S.weight < 50 && !c.rows.isEmpty {
            let p = Int((wf() * 100).rounded())
            A.append(AlertItem(lv: .info, ty: L("低体重", "Low body weight"),
                               t: L("体重 \(num(S.weight)) kg 低于 50 kg，宜取常用量下限。超量提醒已按常用上限的 \(p)% 计算，克数不会自动修改。",
                                    "At \(num(S.weight)) kg (under 50 kg), stay near the low end of usual doses. Overdose alerts now use \(p)% of the usual maximum; grams are not changed automatically.")))
        }
        if c.T <= -1.5 {
            A.append(AlertItem(lv: .amber, ty: L("整体寒凉", "Overall cold"),
                               t: L("全方药性偏寒（\(num(c.T))），脾胃虚寒、经期女性不宜久服，可加生姜 2–3 片或大枣佐之。",
                                    "The formula is cold overall (\(num(c.T))). Not for long-term use with a weak, cold digestion or during menstruation; add 2–3 slices of ginger or a few jujubes to balance it.")))
        }
        if c.T >= 1.8 {
            A.append(AlertItem(lv: .amber, ty: L("整体温热", "Overall hot"),
                               t: L("全方药性偏热（\(num(c.T))），易上火、口干者慎用，夏季慎用。",
                                    "The formula is hot overall (\(num(c.T))). Use with care if you tend toward “internal heat” or dry mouth, and in summer.")))
        }
        if c.ni > 0.9 {
            A.append(AlertItem(lv: .amber, ty: L("滋腻碍胃", "Heavy on digestion"),
                               t: L("滋腻药比重较大，可能导致腹胀纳呆，建议加陈皮 3–6 g 或砂仁 3 g 理气醒脾。",
                                    "Rich, cloying tonics dominate and may cause bloating and poor appetite. Add 3–6 g tangerine peel or 3 g amomum to keep things moving.")))
        }
        let cold = c.rows.filter { $0.h.t <= -1 }.count
        let hot = c.rows.filter { $0.h.t >= 1.5 }.count
        if cold > 0 && hot > 0 {
            A.append(AlertItem(lv: .info, ty: L("寒热并用", "Hot and cold combined"),
                               t: L("方中寒凉与温热药同用，彼此制约偏性。若非有意配伍，整体效果可能相互抵消。",
                                    "Cold and hot herbs are used together and temper each other. If this is not intentional, their effects may cancel out.")))
        }
        if S.method == "infuse" && c.G > 40 {
            A.append(AlertItem(lv: .info, ty: L("药量偏大", "Too much to steep"),
                               t: L("泡水总量 \(num(c.G)) g 偏多，溶出不完全，建议改为煮或分次冲泡。",
                                    "\(num(c.G)) g is a lot to steep and will not extract fully. Decoct instead, or split it into several brews.")))
        }
        if c.out < 80 && !c.rows.isEmpty {
            A.append(AlertItem(lv: .red, ty: L("水量不足", "Not enough water"),
                               t: L("估算出汤仅 \(c.out) ml，有煮干糊锅风险，请加水或缩短时间。",
                                    "Estimated yield is only \(c.out) ml — the pot may boil dry and scorch. Add water or shorten the time.")))
        }
        if A.isEmpty {
            A.append(AlertItem(lv: .ok, ty: L("未见明显问题", "No issues found"),
                               t: L("配伍、剂量与烹制方式均在常规范围内。", "Combination, doses and preparation are all within normal ranges.")))
        }
        return A.enumerated().sorted { $0.element.lv.rawValue != $1.element.lv.rawValue ? $0.element.lv.rawValue < $1.element.lv.rawValue : $0.offset < $1.offset }.map { $0.element }
    }

    // MARK: 体质、服法、不宜人群

    func bodyFit(_ c: Calc) -> BodyFit {
        guard let b = db.bodies[S.body], !b.want.isEmpty else {
            let extra = abs(c.T) > 1 ? L("本方偏性较明显，不宜长期饮用。", " This formula has a clear bias and is not for long-term use.") : ""
            return BodyFit(score: nil, lab: "", notes: [L("平和体质无明显偏颇，保健方以平性、小剂量、不长期单一为原则。",
                                                          "A balanced constitution has no marked tendency. Wellness drinks should be mild, low-dose and varied rather than one formula long-term.") + extra],
                           bad: false)
        }
        var R: [String] = []
        let sc = b.want.reduce(0) { $0 + c.tagN[$1] }
        let T = c.T
        let bn = bodyN(S.body)
        if ["阳虚", "气虚"].contains(S.body) && T < -0.3 {
            R.append(L("方性偏凉（\(num(T))），\(S.body)者久服易伤脾阳。", "The formula is cool (\(num(T))); with a \(bn.lowercased()) constitution, prolonged use can damage spleen yang."))
        }
        if ["阴虚", "湿热"].contains(S.body) && T > 0.5 {
            let yin = S.body == "阴虚"
            R.append(L("方性偏温（\(num(T))），\(yin ? "恐助热伤阴" : "易助湿热")。", "The formula is warm (\(num(T))) and may \(yin ? "add heat and deplete yin" : "aggravate damp-heat")."))
        }
        if S.body == "阴虚" && c.fl["辛"] > 0.35 {
            R.append(L("辛味偏多，辛散易耗伤阴液。", "Pungent flavor is high; its dispersing action can deplete yin fluids."))
        }
        if ["痰湿", "湿热", "气郁"].contains(S.body) && c.ni > 0.6 {
            R.append(L("滋腻药偏多，易助湿碍气。", "Many cloying tonics; they can breed dampness and block qi."))
        }
        if S.body == "气虚" && c.tagN["理气"] > 0.3 { R.append(L("理气药比重大，久服耗气。", "Qi-moving herbs dominate; long-term use can drain qi.")) }
        if S.body == "血瘀" && c.tagN["收敛"] > 0.25 { R.append(L("收涩药较多，不利血行。", "Many astringent herbs, which do not help blood flow.")) }
        if S.body == "特禀" {
            R.append(L("过敏体质首次饮用宜从小剂量试服，花类（菊花、金银花等）尤需留意。",
                       "With allergies, start with a small test amount, especially with flowers such as chrysanthemum and honeysuckle."))
        }
        let p = Int((sc * 100).rounded())
        let i = p >= 45 ? 0 : (p >= 25 ? 1 : (p >= 10 ? 2 : 3))
        let lab = L(["很契合", "较契合", "一般", "针对性弱"][i], ["a strong match", "a good match", "a partial match", "a weak match"][i])
        let wantEn = b.want.map(tagN).joined(separator: ", ").lowercased()
        R.insert(L("\(S.body)（\(b.d)）宜侧重：\(b.want.joined(separator: "、"))。本方相关功效占 \(p)%，\(lab)。",
                   "\(bn) (\(bodyD(S.body))) benefits most from: \(wantEn). These make up \(p)% of this formula’s actions — \(lab)."), at: 0)
        return BodyFit(score: p, lab: lab, notes: R, bad: R.count > 1)
    }

    func advice(_ c: Calc, _ d: Dosing) -> [String] {
        let k = topTags(c, 1).first?.0 ?? ""
        var when = L("温服", "Drink warm")
        if ["补气", "养血", "滋阴", "温阳", "健脾", "固表", "强筋"].contains(k) {
            when = L("饭前约 1 小时温服，补益药空腹吸收较好", "Drink warm about 1 hour before meals; tonics absorb better on an empty stomach")
        } else if k == "消食" {
            when = L("饭后 30 分钟服", "Drink 30 minutes after meals")
        } else if k == "安神" {
            when = L("睡前 30–60 分钟服", "Drink 30–60 minutes before bed")
        } else if ["清热", "疏风", "解毒", "利咽", "明目"].contains(k) {
            when = L("饭后温服，或代茶少量频饮", "Drink warm after meals, or sip through the day like tea")
        }
        let how: String
        if S.method == "infuse" {
            let hard = c.rows.contains { ["root", "bark", "stem", "fungus", "seed"].contains($0.h.p) }
            how = hard ? L("可续水冲泡 1–2 次，味淡即止，当日饮完。", "Re-steep 1–2 times until the taste fades; finish within the day.")
                       : L("可续水冲泡 2–3 次，味淡即止，当日饮完。", "Re-steep 2–3 times until the taste fades; finish within the day.")
        } else {
            how = L("每日 1 剂，药渣可加水复煎一次（约 20 分钟），两次药液合并，分早晚 2 次服。",
                    "One batch per day. Re-boil the dregs once (about 20 minutes), combine both liquids, and drink in two portions, morning and evening.")
        }
        let cycle = L("按当前配方，建议连续服用不超过 \(d.maxDays) 天，之后停 \(d.rest) 天观察身体反应再决定是否续服。",
                      "With this formula, take it for no more than \(d.maxDays) days in a row, then pause \(d.rest) days and see how you feel before continuing.")
        return [when, how, cycle]
    }

    func unsuitable(_ c: Calc) -> [String] {
        var R: [String] = []
        if c.T <= -0.6 { R.append(L("脾胃虚寒、畏寒便溏者", "People with a weak, cold digestion, who feel cold or have loose stools")) }
        if c.T >= 0.6 { R.append(L("阴虚火旺、易上火、口舌生疮者", "People prone to “internal heat”, dry mouth or mouth ulcers")) }
        if c.ni > 0.6 { R.append(L("湿阻中满、舌苔厚腻、消化不良者", "People with bloating, a thick greasy tongue coat or poor digestion")) }
        if c.tagN["活血"] > 0.15 { R.append(L("月经过多、有出血倾向或术前术后者", "Heavy periods, bleeding tendency, or around surgery")) }
        if c.tagN["润肠"] > 0.12 { R.append(L("大便溏泄者", "People with loose stools")) }
        if c.tagN["收敛"] > 0.15 { R.append(L("外感初起、内有实邪者", "At the start of a cold or with an acute excess condition")) }
        if c.tagN["补气"] + c.tagN["温阳"] > 0.35 { R.append(L("感冒发热期间（宜暂停补益）", "During a cold or fever (pause tonics)")) }
        if c.rows.contains(where: { $0.h.id == "chaye" }) { R.append(L("失眠、心律失常者（含咖啡因）", "Insomnia or heart-rhythm problems (contains caffeine)")) }
        if c.rows.contains(where: { $0.h.preg > 0 }) { R.append(L("孕妇（方中有孕期慎用或禁用药）", "Pregnancy (contains herbs to use with caution or avoid)")) }
        return R.isEmpty ? [L("无明显偏性禁忌，但感冒发热、急性病期间宜暂停", "No specific contraindication, but pause during colds, fevers or acute illness")] : R
    }

    // MARK: 文字推演

    /// 综合评估（Markdown，**加粗**）
    func summary(_ c: Calc) -> String {
        let tt = topTags(c, 4)
        let nat = natLabel(c.T)
        let fls = Array(c.fl.sortedDesc().filter { $0.1 > 0.12 }.map { $0.0 }.prefix(2))
        let mers = c.mer.sortedDesc().prefix(3).map { $0.0 }
        let elTop = c.el.sortedDesc().first?.0 ?? "土"
        let t1 = tt.first?.0 ?? "补气"
        let t2 = tt.count > 1 ? tt[1].0 : nil
        let t3 = tt.count > 2 ? tt[2].0 : nil
        if !isEN {
            let fz = fls.isEmpty ? "甘" : fls.joined(separator: "、")
            var s = "本方共 **\(c.rows.count)** 味，总重 **\(num(c.G))** g，以**\(S.method == "infuse" ? "泡水" : "煎煮")**法取汁约 \(c.out) ml。"
            s += "整体药性**\(nat)**，味以\(fz)为主，主入\(mers.joined(separator: "、"))经，五行偏\(elTop)。"
            s += "功效以**\(tagD(t1))**" + (t2.map { "、**\(tagD($0))**" } ?? "") + "为主" + (t3.map { "，兼能\(tagD($0))" } ?? "") + "。"
            return s
        }
        let natEn = natT(nat).lowercased()
        let flEn = (fls.isEmpty ? ["甘"] : fls).map { flN($0).lowercased() }.joined(separator: T(" and "))
        var s = T("This formula has **\(c.rows.count)** herbs weighing **\(num(c.G))** g in total, **\(S.method == "infuse" ? "steeped" : "decocted")** to about \(c.out) ml.") + " "
        s += T("Overall nature is **\(natEn)**; the taste is mainly \(flEn); it enters mainly the \(mers.map(merN).joined(separator: ", ")) channels and leans toward \(elN(elTop)) in the Five Phases.") + " "
        let mainActions = t2.map { T("Its main actions are **\(tagD(t1))** and **\(tagD($0))**") } ?? T("Its main actions are **\(tagD(t1))**")
        s += mainActions + (t3.map { T(", with secondary \(tagD($0))") } ?? "") + "."
        return s
    }

    func fits(_ c: Calc) -> [String] {
        topTags(c, 3).map { tagF($0.0) }.filter { $0 != "—" && !$0.isEmpty }
    }

    func wuxingText(_ el: OrderedSum) -> [String] {
        let D = DB.shared.data
        let o = el.sortedDesc()
        guard o.count == 5 else { return [] }
        let (e1, p1) = o[0]
        let (e5, p5) = o[4]
        var R: [String] = []
        if p1 - p5 < 0.12 {
            R.append(L("五行分布较均衡，药力平和，适合日常调养。", "The Five Phases are fairly balanced; the formula is gentle and suited to everyday maintenance."))
        } else {
            R.append(L("以**\(e1)**为主（\(pct(p1))），药力重在\(D.org[e1] ?? "")。",
                       "**\(elN(e1))** dominates (\(pct(p1))); the formula acts mainly on the \(orgN(e1))."))
        }
        if p1 > 0.36, let ke = KE[e1] {
            let prot = D.protect[ke]
            R.append(L("\(e1)气偏盛，长期单用时需防相乘：\(D.cheng[e1] ?? "")；过盛时还可能\(D.wu[e1] ?? "")。可酌加\(prot?.zh ?? "")之品以护\(D.org[ke] ?? "")。",
                       "\(elN(e1)) is strong. With long-term use alone, watch for overacting: \(chengT(e1)). In excess it may also \(wuT(e1)). Consider adding \(protectT(ke)) herbs to protect the \(orgN(ke))."))
        }
        for m in EL {
            if let ch = SHENG[m], el[m] > 0.17, el[ch] > 0.17 {
                R.append(isEN ? shengT(m) + "." : (D.sheng[m] ?? "") + "。")
            }
        }
        if p5 < 0.06 && p1 - p5 >= 0.12 {
            R.append(L("\(e5)（\(D.org[e5] ?? "")）几乎未涉及。", "\(elN(e5)) (\(orgN(e5))) is barely addressed."))
        }
        return R
    }

    func combos(_ c: Calc) -> [ComboHit] {
        let ids = Set(c.rows.map { $0.h.id })
        return db.data.combos.filter { matchCombo($0, ids) }.map { x in
            var line: String? = nil
            var ok = true
            if let rt = x.ratio, let a = c.rows.first(where: { $0.h.id == rt.a }), let b = c.rows.first(where: { $0.h.id == rt.b }), b.g > 0 {
                let r = a.g / b.g
                ok = abs(r - rt.r) / rt.r <= 0.25
                let dev: String
                if rt.a == "huangqi" {
                    dev = r < rt.r ? L("补血活血力增而补气生血之意减弱", "more blood-nourishing, less of the “qi generates blood” intent")
                                   : L("益气之力更专", "more focused on tonifying qi")
                } else {
                    let heavy = r < rt.r ? b.h : a.h
                    dev = L("\(hnShort(heavy))比重偏大", "\(hnShort(heavy)) is proportionally heavier")
                }
                let head = L("当前比例", "Current ratio") + " \(num(r)) : 1 — "
                line = head + (ok ? L("符合原方比例", "matches the classical ratio")
                                  : L("偏离原方 \(num(rt.r)):1", "deviates from the classical \(num(rt.r)):1") + L("，", ", ") + dev)
            }
            return ComboHit(id: x.n, name: cName(x), text: cText(x), ratioLine: line, ratioOK: ok)
        }
    }

    // MARK: 汤液

    func concLabel(_ x: Double) -> String {
        let i = x < 1 ? 0 : (x < 2.5 ? 1 : (x < 6 ? 2 : (x < 10 ? 3 : 4)))
        return L(["很淡", "清淡", "适中", "浓", "很浓"][i], ["Very light", "Light", "Medium", "Strong", "Very strong"][i])
    }

    func tasteText(_ c: Calc) -> String {
        // 每种组合写成整句，便于翻译
        let main: [String: String] = ["酸": L("酸为主", "mainly sour"), "苦": L("苦为主", "mainly bitter"), "甘": L("甘甜为主", "mainly sweet"),
                                      "辛": L("辛香为主", "mainly spicy-aromatic"), "咸": L("微咸为主", "mainly slightly salty")]
        let hint: [String: String] = ["酸": L("带酸", "a hint of sour"), "苦": L("带苦", "a hint of bitter"), "甘": L("带甘甜", "a hint of sweet"),
                                      "辛": L("带辛香", "a hint of spicy-aromatic"), "咸": L("带微咸", "a hint of slightly salty")]
        var parts: [String] = []
        for (k, v) in c.fl.sortedDesc() {
            if v > 0.35 { parts.append(main[k] ?? k) }
            else if v > 0.15 { parts.append(hint[k] ?? k) }
        }
        return parts.isEmpty ? L("味淡", "mild") : parts.joined(separator: L("，", ", "))
    }

    func waterHint(_ c: Calc) -> String {
        guard !c.rows.isEmpty else { return "" }
        let sug: Int
        if S.method == "boil" {
            sug = Int(((c.G * 8 + S.minutes * 2.5 + 200) / 50).rounded()) * 50
        } else {
            sug = max(250, Int((c.G * 25 / 50).rounded()) * 50)
        }
        return S.method == "boil"
            ? L("按本方药量，建议加水约 \(sug) ml（没过药面 2–3 cm，武火煮沸后转文火）。",
                "For this amount of herbs, use about \(sug) ml of water (2–3 cm above the herbs; bring to a boil on high, then simmer on low).")
            : L("按本方药量，建议加水约 \(sug) ml，可续水冲泡。", "For this amount of herbs, use about \(sug) ml of water; you can top up and re-steep.")
    }

    /// 汤色 RGB（0–1）
    func brewRGB(_ c: Calc, dark: Bool) -> (Double, Double, Double) {
        let baseDark: (Double, Double, Double) = (42.0 / 255.0, 45.0 / 255.0, 40.0 / 255.0)
        let baseLight: (Double, Double, Double) = (243.0 / 255.0, 241.0 / 255.0, 228.0 / 255.0)
        let base = dark ? baseDark : baseLight
        guard !c.rows.isEmpty else { return base }
        var w = 0.0
        var rgb = (0.0, 0.0, 0.0)
        for r in c.rows {
            let x = hexRGB(r.h.col)
            rgb.0 += x.0 * r.ex; rgb.1 += x.1 * r.ex; rgb.2 += x.2 * r.ex
            w += r.ex
        }
        if w > 0 { rgb = (rgb.0 / w, rgb.1 / w, rgb.2 / w) }
        let k = 1 - exp(-c.conc / 4)
        return (base.0 * (1 - k) + rgb.0 * k, base.1 * (1 - k) + rgb.1 * k, base.2 * (1 - k) + rgb.2 * k)
    }
}

func hexRGB(_ s: String) -> (Double, Double, Double) {
    let v = UInt32(s.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0x888888
    return (Double((v >> 16) & 0xFF) / 255, Double((v >> 8) & 0xFF) / 255, Double(v & 0xFF) / 255)
}
