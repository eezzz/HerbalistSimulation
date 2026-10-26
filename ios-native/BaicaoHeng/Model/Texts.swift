import Foundation

// MARK: - 语言

enum Lang: String, Codable, CaseIterable {
    case en, zh, es, pt

    /// 在设置里显示的名称（各用本语言书写）
    var nativeName: String {
        switch self {
        case .en: return "English"
        case .zh: return "中文"
        case .es: return "Español"
        case .pt: return "Português"
        }
    }

    var localeID: String {
        switch self {
        case .en: return "en"
        case .zh: return "zh-Hans"
        case .es: return "es"
        case .pt: return "pt-BR"
        }
    }
}

/// 当前界面语言。由 AppState 在语言切换时更新，界面在同一次刷新中读取。
enum Loc {
    static var lang: Lang = .en
}

/// 非中文界面（英文、西班牙文、葡萄牙文）都以英文原文为底本，再经 T() 翻译
var isEN: Bool { Loc.lang != .zh }
/// 西语、葡语比英文长，部分版面改为换行或上下排列；中英文版面不变
var isLongLang: Bool { Loc.lang == .es || Loc.lang == .pt }

/// 中文界面用 zh；其他语言用英文原文 en 经 T() 翻译
func L(_ zh: String, _ en: String) -> String { Loc.lang == .zh ? zh : T(en) }

/// 把英文原文翻译成当前语言（西语 / 葡语）。英文界面原样返回。
/// 先查整句对照表；查不到时按带占位符的句式模板匹配（如 “{0} g/day”），占位内容若在对照表中也一并翻译。
func T(_ en: String) -> String {
    switch Loc.lang {
    case .en, .zh: return en
    case .es, .pt: return Translator.shared.translate(en, Loc.lang.rawValue)
    }
}

final class Translator {
    static let shared = Translator()

    private struct Template {
        let regex: NSRegularExpression
        let target: String
        let slots: Int
    }

    private var compiled: [String: [Template]] = [:]
    private var memo: [String: [String: String]] = [:]

    func translate(_ en: String, _ lang: String) -> String {
        guard !en.isEmpty, let pack = DB.shared.data.packs?[lang] else { return en }
        if let hit = memo[lang]?[en] { return hit }
        var out = en
        if let exact = pack.strings[en] {
            out = exact
        } else {
            let range = NSRange(en.startIndex..., in: en)
            for t in templates(lang, pack) {
                guard let m = t.regex.firstMatch(in: en, options: [], range: range) else { continue }
                var r = t.target
                for i in 0..<t.slots {
                    guard let rr = Range(m.range(at: i + 1), in: en) else { continue }
                    let piece = String(en[rr])
                    r = r.replacingOccurrences(of: "{\(i)}", with: piece.count < en.count ? translate(piece, lang) : piece)
                }
                out = r
                break
            }
        }
        memo[lang, default: [:]][en] = out
        return out
    }

    private func literalLength(_ s: String) -> Int {
        s.replacingOccurrences(of: #"\{\d+\}"#, with: "", options: .regularExpression).count
    }

    private func templates(_ lang: String, _ pack: LangPack) -> [Template] {
        if let c = compiled[lang] { return c }
        // 文字部分越长的模板越具体，优先匹配
        let sorted = pack.templates.filter { $0.count == 2 }.sorted { literalLength($0[0]) > literalLength($1[0]) }
        var out: [Template] = []
        for pair in sorted {
            var pattern = "^"
            var slots = 0
            var rest = Substring(pair[0])
            while let r = rest.range(of: #"\{\d+\}"#, options: .regularExpression) {
                pattern += NSRegularExpression.escapedPattern(for: String(rest[..<r.lowerBound]))
                pattern += "(.*?)"
                slots += 1
                rest = rest[r.upperBound...]
            }
            pattern += NSRegularExpression.escapedPattern(for: String(rest)) + "$"
            if let re = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
                out.append(Template(regex: re, target: pair[1], slots: slots))
            }
        }
        compiled[lang] = out
        return out
    }
}

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

// MARK: - 文本查找（中文直接取；其他语言取英文原文再经 T() 翻译）

private var D: HerbData { DB.shared.data }

func EH(_ h: Herb) -> ENHerb? { D.en.herbs[h.id] }
func hn(_ h: Herb) -> String { isEN ? T(EH(h)?.n ?? h.n) : h.n }
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
func hg(_ h: Herb) -> String { isEN ? T(EH(h)?.g ?? h.g) : h.g }
func hc(_ h: Herb) -> String { isEN ? T(EH(h)?.c ?? h.c) : h.c }
func hw(_ h: Herb) -> String { isEN ? T(EH(h)?.w ?? h.w) : h.w }
func hix(_ h: Herb) -> [String] { isEN ? (EH(h)?.ix ?? h.ix).map(T) : h.ix }
func hnote(_ h: Herb) -> String { isEN ? T(EH(h)?.note ?? h.note) : h.note }
func hform(_ h: Herb) -> String { L(h.formZh, h.formEn) }
func formNoteText() -> String { L(DB.shared.data.formNote.zh, DB.shared.data.formNote.en) }
func hwarn(_ h: Herb) -> String { isEN ? T(EH(h)?.warn ?? h.warn) : h.warn }

func natT(_ k: String) -> String { isEN ? T(D.nat[k] ?? k) : k }
func flavT(_ f: String) -> String {
    isEN ? f.map { T(D.fl[String($0)] ?? String($0)) }.joined(separator: "/") : f
}
func flN(_ f: String) -> String { isEN ? T(D.fl[f] ?? f) : f }
func merT(_ h: Herb) -> String { isEN ? h.mer.map { T(D.mer[$0] ?? $0) }.joined(separator: ", ") : h.m }
func merN(_ m: String) -> String { isEN ? T(D.mer[m] ?? m) : m }
func elN(_ e: String) -> String { isEN ? T(D.el[e] ?? e) : e }
func orgN(_ e: String) -> String { isEN ? T(D.orgEn[e] ?? "") : (D.org[e] ?? "") }
func shengT(_ e: String) -> String { L(D.sheng[e] ?? "", D.shengEn[e] ?? "") }
func chengT(_ e: String) -> String { L(D.cheng[e] ?? "", D.chengEn[e] ?? "") }
func wuT(_ e: String) -> String { L(D.wu[e] ?? "", D.wuEn[e] ?? "") }
func protectT(_ e: String) -> String { L(D.protect[e]?.zh ?? "", D.protect[e]?.en ?? "") }

func tagN(_ k: String) -> String { isEN ? T(DB.shared.tags[k]?.enName ?? k) : k }
func tagD(_ k: String) -> String { isEN ? T(DB.shared.tags[k]?.enD ?? k) : (DB.shared.tags[k]?.d ?? k) }
func tagF(_ k: String) -> String { isEN ? T(DB.shared.tags[k]?.enFit ?? "") : (DB.shared.tags[k]?.fit ?? "") }

func catN(_ c: String) -> String { isEN ? T(D.cats.first { $0.k == c }?.en ?? c) : c }
func pcatN(_ c: String) -> String { isEN ? T(D.pcats.first { $0.k == c }?.en ?? c) : c }
func bodyN(_ k: String) -> String { isEN ? T(DB.shared.bodies[k]?.enName ?? k) : k }
func bodyD(_ k: String) -> String { isEN ? T(DB.shared.bodies[k]?.enD ?? "") : (DB.shared.bodies[k]?.d ?? "") }
func roleN(_ r: String) -> String { isEN ? T(D.roleEn[r] ?? r) : r }
func partN(_ p: String) -> String { let x = DB.shared.part(p); return isEN ? T(x.en) : x.lab }

func pName(_ p: Preset) -> String { isEN ? T(D.en.presets[p.n]?.n ?? p.n) : p.n }
func pSrc(_ p: Preset) -> String { isEN ? T(D.en.presets[p.n]?.src ?? p.src) : p.src }
func pDesc(_ p: Preset) -> String { isEN ? T(D.en.presets[p.n]?.d ?? p.d) : p.d }
func cName(_ x: Combo) -> String { isEN ? T(D.en.combos[x.n]?.n ?? x.n) : x.n }
func cText(_ x: Combo) -> String { isEN ? T(D.en.combos[x.n]?.t ?? x.t) : x.t }

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
