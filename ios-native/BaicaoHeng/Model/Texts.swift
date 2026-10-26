import Foundation

// MARK: - 语言

enum Lang: String, Codable {
    case zh, en
}

/// 当前界面语言。由 AppState 在语言切换时更新，界面在同一次刷新中读取。
enum Loc {
    static var lang: Lang = .zh
}

func L(_ zh: String, _ en: String) -> String { Loc.lang == .en ? en : zh }
var isEN: Bool { Loc.lang == .en }
func COLON() -> String { L("：", ": ") }
func SEP() -> String { L("；", "; ") }
func joinList(_ a: [String]) -> String { a.joined(separator: L("、", ", ")) }

// MARK: - 数字格式

func clamp(_ v: Double, _ a: Double, _ b: Double) -> Double { max(a, min(b, v)) }
func r1(_ v: Double) -> Double { (v * 10).rounded() / 10 }
/// 保留至多 1 位小数，整数不带 .0
func num(_ v: Double) -> String {
    let r = r1(v)
    return r == r.rounded() ? String(Int(r)) : String(r)
}
func pct(_ v: Double) -> String { "\(Int((v * 100).rounded()))%" }
func signed(_ v: Double) -> String { (v > 0 ? "+" : "") + num(v) }

// MARK: - 文本查找（中英）

private var D: HerbData { DB.shared.data }

func EH(_ h: Herb) -> ENHerb? { D.en.herbs[h.id] }
func hn(_ h: Herb) -> String { isEN ? (EH(h)?.n ?? h.n) : h.n }
func hnShort(_ h: Herb) -> String {
    guard isEN else { return h.n }
    var s = hn(h)
    if let r = s.range(of: #"\s*\(.*\)\s*$"#, options: .regularExpression) { s.removeSubrange(r) }
    return s
}
func hpy(_ h: Herb) -> String {
    if let n = EH(h)?.n, let a = n.firstIndex(of: "("), let b = n.lastIndex(of: ")"), a < b {
        return String(n[n.index(after: a)..<b])
    }
    return h.py
}
func hg(_ h: Herb) -> String { isEN ? (EH(h)?.g ?? h.g) : h.g }
func hc(_ h: Herb) -> String { isEN ? (EH(h)?.c ?? h.c) : h.c }
func hw(_ h: Herb) -> String { isEN ? (EH(h)?.w ?? h.w) : h.w }
func hix(_ h: Herb) -> [String] { isEN ? (EH(h)?.ix ?? h.ix) : h.ix }
func hnote(_ h: Herb) -> String { isEN ? (EH(h)?.note ?? h.note) : h.note }
func hform(_ h: Herb) -> String { L(h.formZh, h.formEn) }
func formNoteText() -> String { L(DB.shared.data.formNote.zh, DB.shared.data.formNote.en) }
func hwarn(_ h: Herb) -> String { isEN ? (EH(h)?.warn ?? h.warn) : h.warn }

func natT(_ k: String) -> String { isEN ? (D.nat[k] ?? k) : k }
func flavT(_ f: String) -> String {
    isEN ? f.map { D.fl[String($0)] ?? String($0) }.joined(separator: "/") : f
}
func flN(_ f: String) -> String { isEN ? (D.fl[f] ?? f) : f }
func merT(_ h: Herb) -> String { isEN ? h.mer.map { D.mer[$0] ?? $0 }.joined(separator: ", ") : h.m }
func merN(_ m: String) -> String { isEN ? (D.mer[m] ?? m) : m }
func elN(_ e: String) -> String { isEN ? (D.el[e] ?? e) : e }
func orgN(_ e: String) -> String { isEN ? (D.orgEn[e] ?? "") : (D.org[e] ?? "") }

func tagN(_ k: String) -> String { isEN ? (DB.shared.tags[k]?.enName ?? k) : k }
func tagD(_ k: String) -> String { isEN ? (DB.shared.tags[k]?.enD ?? k) : (DB.shared.tags[k]?.d ?? k) }
func tagF(_ k: String) -> String { isEN ? (DB.shared.tags[k]?.enFit ?? "") : (DB.shared.tags[k]?.fit ?? "") }

func catN(_ c: String) -> String { isEN ? (D.cats.first { $0.k == c }?.en ?? c) : c }
func pcatN(_ c: String) -> String { isEN ? (D.pcats.first { $0.k == c }?.en ?? c) : c }
func bodyN(_ k: String) -> String { isEN ? (DB.shared.bodies[k]?.enName ?? k) : k }
func bodyD(_ k: String) -> String { isEN ? (DB.shared.bodies[k]?.enD ?? "") : (DB.shared.bodies[k]?.d ?? "") }
func roleN(_ r: String) -> String { isEN ? (D.roleEn[r] ?? r) : r }
func partN(_ p: String) -> String { let x = DB.shared.part(p); return isEN ? x.en : x.lab }

func pName(_ p: Preset) -> String { isEN ? (D.en.presets[p.n]?.n ?? p.n) : p.n }
func pSrc(_ p: Preset) -> String { isEN ? (D.en.presets[p.n]?.src ?? p.src) : p.src }
func pDesc(_ p: Preset) -> String { isEN ? (D.en.presets[p.n]?.d ?? p.d) : p.d }
func cName(_ x: Combo) -> String { isEN ? (D.en.combos[x.n]?.n ?? x.n) : x.n }
func cText(_ x: Combo) -> String { isEN ? (D.en.combos[x.n]?.t ?? x.t) : x.t }

/// 西方草药的出处说明
func westNote(_ h: Herb) -> String? {
    switch h.west {
    case 1:
        return L("西方草药：剂量参照德国 Commission E / EMA 专论；性味归经为中西结合文献（Holmes、Ross 等）的参考归类，非药典记载。",
                 "Western herb: doses follow German Commission E / EMA monographs; the nature, flavor and meridian entries are reference attributions from integrative literature (Holmes, Ross), not pharmacopoeial.")
    case 2:
        return L("中西通用：性味归经据《中国药典》，西方用法参照 Commission E。",
                 "Used in both traditions: nature and meridians per the Chinese Pharmacopoeia; Western use per Commission E.")
    default:
        return nil
    }
}

let disclaimerText: () -> String = {
    L("本工具依据《中国药典》常用量、德国 Commission E / EMA 专论与中医药性理论做教学推演，不能替代医师辨证。慢病、服药中、孕期及儿童请先咨询医师或药师。",
      "An educational model based on Chinese Pharmacopoeia dose ranges, German Commission E / EMA monographs and TCM materia medica theory. It does not replace diagnosis by a qualified practitioner. With a chronic condition, current medication, pregnancy, or for children, consult a physician or pharmacist first.")
}

let methodNoteText: () -> String = {
    L("药性数值化：寒 −2、凉 −1.2、微寒 −1、平 0、微温 +1、温 +1.5、热 +2、大热 +3。溶出率指单次煎/泡中有效成分转移到汤液的比例：受固液平衡限制，规范头煎一般只有 30–55%，复煎后合计约 50–70%。药力 = 实际克数 ÷ 常用量中值 × （本次溶出率 ÷ 标准制法溶出率）。五行按“五味入五脏”（酸木、苦火、甘土、辛金、咸水）与归经脏腑各半折算。",
      "Nature is scored Cold −2, Cool −1.2, Slightly cold −1, Neutral 0, Slightly warm +1, Warm +1.5, Hot +2, Very hot +3. Extraction rate is the share of active constituents transferred to the liquid in one pass; solid–liquid equilibrium caps it at about 30–55% for a proper first decoction and 50–70% after a second boil. Potency = grams ÷ usual-dose midpoint × (this extraction ÷ standard-preparation extraction). Five-Phase shares combine the five flavors (sour→Wood, bitter→Fire, sweet→Earth, pungent→Metal, salty→Water) and the meridian organs, half each.")
}
