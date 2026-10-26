import Foundation

// MARK: - 数据结构（与 Resources/herbdata.json 一一对应；该文件由 scripts/export-herbdata.cjs 从网页版导出）

struct KV: Codable, Hashable {
    let k: String
    let v: Double
}

struct Herb: Codable, Identifiable, Hashable {
    let id: String
    let n: String          // 中文名
    let py: String         // 拼音 / 英文检索词
    let cat: String        // 药柜分类
    let tl: String         // 四气标签：寒、凉、平、温……
    let t: Double          // 四气数值
    let f: String          // 五味（每个字一种）
    let m: String          // 归经原文
    let mer: [String]      // 归经拆分
    let d: [Double]        // 常用日量 [下限, 上限] g
    let p: String          // 部位
    let fx: [KV]           // 功效权重（保持原顺序）
    let g: String          // 功效
    let c: String          // 主要成分
    let w: String          // 注意
    let col: String        // 汤色
    let sp: [String]       // 特殊煎法
    let ix: [String]       // 药物相互作用
    let preg: Int          // 0 无，1 孕期慎用，2 孕期禁用
    let ni: Double         // 滋腻程度
    let tox: Int
    let raw: Int
    let west: Int          // 0 中药，1 西方草药，2 中西通用
    let warn: String
    let formZh: String     // 规格：鲜品 / 饮片 / 炮制品
    let formEn: String
    let formLv: Int        // 0 说明，1 不可互换，2 必须用炮制品（生品有害）
    let note: String
    let std: String        // "infuse" 表示标准制法为浸泡
    let infK: Double
    let ti: Double

    var dMin: Double { d[0] }
    var dMax: Double { d[1] }
    var mid: Double { (d[0] + d[1]) / 2 }
    func has(_ s: String) -> Bool { sp.contains(s) }
    func fxValue(_ k: String) -> Double { fx.first { $0.k == k }?.v ?? 0 }
}

struct PartInfo: Codable {
    let E: Double
    let inf: Double
    let ti: Double
    let tb: Double
    let lab: String
    let en: String
}

struct PresetItem: Codable, Hashable {
    let id: String
    let g: Double
}

struct Preset: Codable, Identifiable, Hashable {
    let c: String
    let n: String
    let src: String
    let d: String
    let m: String
    let w: Double
    let mi: Double
    let t: Double
    let soak: Bool
    let items: [PresetItem]
    var id: String { n }
}

struct Ratio: Codable, Hashable {
    let a: String
    let b: String
    let r: Double
}

struct Combo: Codable, Hashable {
    let n: String
    let t: String
    let need: [[String]]   // 每一项为可互相替代的药材
    let ratio: Ratio?
    let jun: [String]
}

struct Conflict: Codable {
    let a: String
    let b: String
    let lv: String
    let ty: String
    let t: String
}

struct LTEntry: Codable {
    let days: Int
    let zh: String
    let en: String
}

struct GancaoLT: Codable {
    let hi: String
    let mid: String
}

struct TagInfo: Codable {
    let k: String
    let d: String
    let fit: String
    let enName: String
    let enD: String
    let enFit: String
}

struct BodyInfo: Codable {
    let k: String
    let want: [String]
    let d: String
    let enName: String
    let enD: String
}

struct CatInfo: Codable {
    let k: String
    let en: String
}

struct ZhEn: Codable {
    let zh: String
    let en: String
}

struct ENHerb: Codable {
    let n: String
    let g: String?
    let c: String?
    let w: String?
    let ix: [String]?
    let note: String?
    let warn: String?
}

struct ENPreset: Codable {
    let n: String
    let src: String?
    let d: String?
}

struct ENCombo: Codable {
    let n: String
    let t: String?
}

struct ENConflict: Codable {
    let ty: String?
    let t: String?
}

struct ENData: Codable {
    let herbs: [String: ENHerb]
    let presets: [String: ENPreset]
    let combos: [String: ENCombo]
    let conflicts: [String: ENConflict]
}

struct Symptom: Codable, Identifiable, Hashable {
    let k: String
    let en: String
    let syn: [String]
    let tags: [KV]
    var id: String { k }
}

/// 一种界面语言的翻译包：英文原文 → 译文；带占位符的句式模板；症状同义词（用于搜索）
struct LangPack: Codable {
    let strings: [String: String]
    let templates: [[String]]
    let symSyn: [String: [String]]
}

struct HerbData: Codable {
    let herbs: [Herb]
    let part: [String: PartInfo]
    let presets: [Preset]
    let combos: [Combo]
    let conflicts: [Conflict]
    let lt: [String: LTEntry]
    let ltGancao: GancaoLT
    let tags: [TagInfo]
    let bodies: [BodyInfo]
    let cats: [CatInfo]
    let pcats: [CatInfo]
    let nat: [String: String]
    let fl: [String: String]
    let mer: [String: String]
    let el: [String: String]
    let org: [String: String]
    let orgEn: [String: String]
    let sheng: [String: String]
    let shengEn: [String: String]
    let cheng: [String: String]
    let chengEn: [String: String]
    let wu: [String: String]
    let wuEn: [String: String]
    let protect: [String: ZhEn]
    let roleEn: [String: String]
    let symptoms: [Symptom]
    let redFlags: [String]
    let crisis: [String]
    let formNote: ZhEn
    let packs: [String: LangPack]?
    let en: ENData
}

// MARK: - 数据库

final class DB {
    static let shared = DB()

    let data: HerbData
    let byId: [String: Herb]
    let tags: [String: TagInfo]
    let bodies: [String: BodyInfo]

    private init() {
        guard let url = Bundle.main.url(forResource: "herbdata", withExtension: "json"),
              let raw = try? Data(contentsOf: url) else {
            fatalError("herbdata.json 未打包进 App")
        }
        do {
            data = try JSONDecoder().decode(HerbData.self, from: raw)
        } catch {
            fatalError("herbdata.json 解析失败：\(error)")
        }
        byId = Dictionary(uniqueKeysWithValues: data.herbs.map { ($0.id, $0) })
        tags = Dictionary(uniqueKeysWithValues: data.tags.map { ($0.k, $0) })
        bodies = Dictionary(uniqueKeysWithValues: data.bodies.map { ($0.k, $0) })
    }

    func part(_ p: String) -> PartInfo {
        data.part[p] ?? PartInfo(E: 0.5, inf: 0.3, ti: 20, tb: 15, lab: p, en: p)
    }
}
