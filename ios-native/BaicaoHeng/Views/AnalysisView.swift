import SwiftUI

struct AnalysisView: View {
    @EnvironmentObject var st: AppState

    static let sectionKeys = ["SYNTHESIS", "DAILY", "CAUTIONS", "NATURE", "WUXING", "ACTIONS", "MERIDIANS", "ROLES", "CONSTITUTION", "CLASSICS", "PHARMACOLOGY"]

    var body: some View {
        let eng = st.engine
        let c = eng.compute()

        NavigationStack {
            Group {
                if c.rows.isEmpty {
                    ContentUnavailableView(L("还没有药方", "No formula yet"),
                                           systemImage: "leaf",
                                           description: Text(L("加入药材并设置克数后，这里会推演药性、五行、归经、功效与注意事项。",
                                                               "Add herbs and set their grams to see nature, Five Phases, meridians, actions and cautions here.")))
                } else {
                    report(eng, c)
                }
            }
            .navigationTitle(L("分析", "Analysis"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { SettingsButton() }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(L("全部展开", "Expand all")) { st.setAllCollapsed(Self.sectionKeys, false) }
                        Button(L("全部收起", "Collapse all")) { st.setAllCollapsed(Self.sectionKeys, true) }
                    } label: {
                        Image(systemName: "rectangle.compress.vertical")
                    }
                    .accessibilityLabel(L("展开或收起全部", "Expand or collapse all"))
                }
            }
            .adBanner()
        }
    }

    private func report(_ eng: Engine, _ c: Calc) -> some View {
        let d = eng.dosing(c)
        let alerts = eng.alerts(c, d)
        let fit = eng.bodyFit(c)
        let roles = eng.roleMap(c)
        let combos = eng.combos(c)

        return List {
            section("SYNTHESIS", L("综合评估", "Overall assessment")) {
                md(eng.summary(c)).font(.body)
                VStack(alignment: .leading, spacing: 4) {
                    SubHeading(text: L("适合人群", "Suited to"))
                    BulletList(items: eng.fits(c))
                }
                VStack(alignment: .leading, spacing: 4) {
                    SubHeading(text: L("不宜人群", "Not suited to"))
                    BulletList(items: eng.unsuitable(c))
                }
                VStack(alignment: .leading, spacing: 4) {
                    SubHeading(text: L("服用建议", "How to take"))
                    BulletList(items: eng.advice(c, d))
                }
            }

            section("DAILY", L("每日总量与疗程", "Daily total & course")) {
                DosingBlock(d: d, days: st.s.days, perDay: st.s.perDay, upper: eng.upper)
            }

            section("CAUTIONS", L("注意事项", "Cautions")) {
                ForEach(alerts) { AlertRow(a: $0) }
            }

            section("NATURE", L("四气 · 五味", "Nature · flavor")) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(natT(natLabel(c.T))).font(.title.weight(.bold)).foregroundStyle(natColor(c.T))
                    Text(L("药性指数", "Nature index") + " " + signed(c.T)).font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                }
                NatureGauge(T: c.T, ticks: c.rows.map { $0.h.t })
                BarList(items: FL5.map { ($0, c.fl[$0]) }, color: { elColor(FL2EL[$0] ?? "土") }, label: flN)
                Text(L("五味入五脏：酸入肝、苦入心、甘入脾、辛入肺、咸入肾。短竖线为各药的单味药性。",
                       "Each flavor enters an organ: sour → liver, bitter → heart, sweet → spleen, pungent → lung, salty → kidney. Small ticks show each herb’s own nature."))
                    .font(.caption).foregroundStyle(.secondary)
            }

            section("WUXING", L("五行推演", "Five Phases")) {
                RadarChart(el: c.el).frame(maxWidth: .infinity)
                ForEach(Array(eng.wuxingText(c.el).enumerated()), id: \.offset) { _, s in
                    md(s).font(.subheadline)
                }
            }

            section("ACTIONS", L("功效构成", "Actions")) {
                BarList(items: Array(c.tagN.sortedDesc().filter { $0.0 != "调和" }.prefix(8)), color: { _ in Color.brand }, label: tagN)
            }

            section("MERIDIANS", L("归经", "Meridians")) {
                BarList(items: Array(c.mer.sortedDesc().prefix(8)), color: { elColor(MER2EL[$0] ?? "土") }, label: merN)
            }

            section("ROLES", L("君臣佐使", "Formula roles")) {
                RolesBlock(c: c, roles: roles)
                Text(L("按“药力 = 克数 ÷ 常用量中值 × 相对溶出率”排序推定，识别到成方时按原方定君药，仅供理解组方思路。",
                       "Ranked by potency = grams ÷ usual-dose midpoint × relative extraction; a recognized classic formula keeps its own sovereign. A guide to formula logic only."))
                    .font(.caption).foregroundStyle(.secondary)
            }

            section("CONSTITUTION", L("体质契合", "Constitution fit")) {
                if let score = fit.score {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("\(score)%").font(.title2.monospacedDigit().weight(.semibold)).foregroundStyle(fit.bad ? Color.alertAmber : Color.alertOK)
                        Text(fit.lab + (fit.bad ? L("，但有需留意之处", ", with points to watch") : "")).font(.subheadline)
                    }
                }
                BulletList(items: fit.notes)
            }

            section("CLASSICS", L("经典配伍", "Classic pairings")) {
                if combos.isEmpty {
                    Text(L("未识别到经典药对或成方。可试试“黄芪 + 当归”“枸杞 + 菊花”“生姜 + 大枣”。",
                           "No classic pairing or formula recognized. Try astragalus + angelica, goji + chrysanthemum, or ginger + jujube."))
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                ForEach(combos) { x in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(x.name).font(.headline)
                        Text(x.text).font(.subheadline)
                        if let line = x.ratioLine {
                            Text(line).font(.subheadline.monospacedDigit().weight(.semibold))
                                .foregroundStyle(x.ratioOK ? Color.alertOK : Color.alertAmber)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            section("PHARMACOLOGY", L("现代药理 · 西医视角", "Modern pharmacology")) {
                let ix = c.rows.flatMap { r in hix(r.h).map { (hnShort(r.h), $0) } }
                SubHeading(text: L("可能的药物相互作用", "Possible drug interactions"))
                if ix.isEmpty {
                    Text(L("方中药材未见常见的显著相互作用记录。", "No commonly reported significant interactions for these herbs."))
                        .font(.subheadline).foregroundStyle(.secondary)
                } else {
                    ForEach(Array(ix.enumerated()), id: \.offset) { _, p in
                        (Text(p.0).bold() + Text(COLON() + p.1)).font(.subheadline)
                    }
                }
                Text(L("正在服用抗凝、降糖、降压、免疫抑制或精神类药物者，饮用前请告知医师或药师。",
                       "If you take anticoagulants, diabetes, blood-pressure, immunosuppressant or psychiatric medication, tell your doctor or pharmacist before drinking."))
                    .font(.caption).foregroundStyle(.secondary)
                SubHeading(text: L("药材档案", "Herb profiles"))
                ForEach(c.rows) { r in
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 6) {
                            profileLine(L("规格", "Form"), hform(r.h))
                            profileLine(L("功效", "Actions"), hg(r.h))
                            profileLine(L("主要成分", "Constituents"), hc(r.h))
                            profileLine(L("注意", "Cautions"), hw(r.h) + (hnote(r.h).isEmpty ? "" : L("（\(hnote(r.h))）", " (\(hnote(r.h)))")))
                            if let w = westNote(r.h) { Text(w).font(.caption).foregroundStyle(.secondary) }
                        }
                        .padding(.vertical, 4)
                    } label: {
                        HStack {
                            Text(hn(r.h)).font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("\(num(r.g)) g · " + L("药力", "potency") + " \(num(r.s))").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section {
                Text(methodNoteText()).font(.caption).foregroundStyle(.secondary)
                Text(disclaimerText()).font(.caption).foregroundStyle(.secondary)
            }
        }
        .listStyle(.sidebar)
    }

    private func section<Content: View>(_ key: String, _ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        Section(isExpanded: st.expandedBinding(key)) {
            content()
        } header: {
            Text(title)
        }
    }

    private func profileLine(_ k: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(k).font(.caption).foregroundStyle(.secondary)
            Text(v).font(.subheadline)
        }
    }
}

struct RolesBlock: View {
    let c: Calc
    let roles: [String: String]

    var body: some View {
        let txt: [String: String] = [
            "君": L("针对主证、药力最大", "addresses the main pattern; strongest"),
            "臣": L("辅助君药加强主效", "reinforces the sovereign’s main action"),
            "佐": L("兼顾次要方面或制约偏性", "covers secondary aspects or checks side effects"),
            "使": L("调和诸药、引经和胃", "harmonizes the formula and protects the stomach"),
        ]
        let jun = c.rows.first { roles[$0.h.id] == "君" }
        VStack(alignment: .leading, spacing: 10) {
            ForEach(["君", "臣", "佐", "使"], id: \.self) { k in
                let hs = c.rows.filter { roles[$0.h.id] == k }
                if !hs.isEmpty {
                    let counter: [String] = (k == "佐" && jun != nil)
                        ? hs.filter { r in
                            guard let j = jun else { return false }
                            return (r.h.t > 0) != (j.h.t > 0) && abs(r.h.t) >= 1 && abs(j.h.t) >= 1
                        }.map { hnShort($0.h) }
                        : []
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(roleN(k))
                            .font(isEN ? .caption.weight(.bold) : .title3.weight(.heavy))
                            .foregroundStyle(k == "君" ? Color.fire : Color.brand)
                            .frame(width: isEN ? 76 : 28, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(hs.map { "\(hnShort($0.h)) \(num($0.g))g" }.joined(separator: L("、", ", "))).font(.subheadline.weight(.semibold))
                            Text((txt[k] ?? "") + (counter.isEmpty ? "" : L("；\(counter.joined(separator: "、"))药性与君药相反，有“佐制”之意",
                                                                              "; \(counter.joined(separator: ", ")) has the opposite nature to the sovereign and acts as a counterbalance")))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct DosingBlock: View {
    let d: Dosing
    let days: Int
    let perDay: Int
    let upper: (Herb) -> Double

    var body: some View {
        let over = days > d.maxDays
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                statBox(L("每日总药量", "Daily total"), "\(num(d.dailyTotal)) g", L("\(perDay) 剂 / 日", "\(perDay) / day"), .primary)
                statBox(L("疗程合计", "Course total"), "\(num(d.courseTotal)) g", L("\(days) 天", "\(days) days"), .primary)
                statBox(L("建议最长连服", "Max. continuous"), "\(d.maxDays)" + L(" 天", " d"), L("之后停 \(d.rest) 天", "then pause \(d.rest) d"), over ? .alertAmber : .alertOK)
            }
            .fixedSize(horizontal: false, vertical: isLongLang)

            VStack(alignment: .leading, spacing: 4) {
                GeometryReader { g in
                    let scale = Double(max(days, d.maxDays)) * 1.15
                    let w = g.size.width
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.alertRed.opacity(0.15)).frame(height: 10)
                        Capsule().fill(Color.alertOK.opacity(0.55)).frame(width: w * CGFloat(Double(d.maxDays) / scale), height: 10)
                        RoundedRectangle(cornerRadius: 2).fill(over ? Color.alertRed : Color.primary)
                            .frame(width: 4, height: 18)
                            .offset(x: min(w - 4, w * CGFloat(Double(days) / scale)))
                    }
                }
                .frame(height: 18)
                HStack {
                    Text(L("第 1 天", "Day 1"))
                    Spacer()
                    Text(L("计划 \(days) 天", "plan: \(days) days"))
                }
                .font(.caption2).foregroundStyle(.secondary)
                Text(L("限制因素：", "Limiting factor: ") + d.binding.joined(separator: SEP()))
                    .font(.caption).foregroundStyle(.secondary)
            }

            if isLongLang {
                compactTable
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    Grid(alignment: .trailing, horizontalSpacing: 14, verticalSpacing: 6) {
                        GridRow {
                            Text(L("药材", "Herb")).gridColumnAlignment(.leading)
                            Text(L("每剂", "g/dose"))
                            Text(L("每日", "g/day"))
                            Text(L("常用日量", "Usual/day"))
                            Text(L("疗程", "Course g"))
                            Text(L("久服上限", "Max days"))
                            Text("")
                        }
                        .font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                        Divider()
                        ForEach(d.rows) { x in
                            let u = upper(x.r.h)
                            let overDay = x.daily > u
                            let tooLong = (x.lt.map { days > $0.days }) ?? false
                            GridRow {
                                Text(hnShort(x.r.h)).gridColumnAlignment(.leading)
                                Text(num(x.r.g))
                                Text(num(x.daily))
                                Text("\(num(x.r.h.dMin))–\(num(u < x.r.h.dMax ? u : x.r.h.dMax))").foregroundStyle(.secondary)
                                Text(num(x.total))
                                Text(x.lt.map { "\($0.days)" + L(" 天", " d") } ?? "—")
                                Text(overDay ? L("超日量", "Over daily") : (tooLong ? L("超久服", "Too long") : L("正常", "OK")))
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 6).padding(.vertical, 1)
                                    .foregroundStyle(overDay || tooLong ? Color.alertAmber : Color.alertOK)
                                    .background(Capsule().fill((overDay || tooLong ? Color.alertAmber : Color.alertOK).opacity(0.15)))
                            }
                            .font(.caption.monospacedDigit())
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            SubHeading(text: L("关键成分每日摄入估算", "Estimated daily intake of key compounds"))
            if d.I.isEmpty {
                Text(L("方中没有需要按成分累计的药材（甘草、肉桂、绿茶、糖类）。", "No herbs here need compound tracking (licorice, cinnamon, green tea, sugars)."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(d.I) { x in IntakeRow(x: x) }
        }
        .padding(.vertical, 4)
    }

    private func statBox(_ k: String, _ v: String, _ sub: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(k).font(.caption2).foregroundStyle(.secondary).lineLimit(isLongLang ? 2 : 1).minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: isLongLang)
            Text(v).font(.title3.monospacedDigit().weight(.semibold)).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.7)
            Text(sub).font(.caption2).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: isLongLang ? .infinity : nil, alignment: .topLeading)
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.track.opacity(0.6)))
    }

    // MARK: 逐味剂量表

    private func status(_ overDay: Bool, _ tooLong: Bool) -> some View {
        Text(twoLines(overDay ? L("超日量", "Over daily") : (tooLong ? L("超久服", "Too long") : L("正常", "OK"))))
            .font(.caption2.weight(.semibold))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 6).padding(.vertical, 1)
            .foregroundStyle(overDay || tooLong ? Color.alertAmber : Color.alertOK)
            .background(Capsule().fill((overDay || tooLong ? Color.alertAmber : Color.alertOK).opacity(0.15)))
    }

    private func flags(_ x: DRow) -> (overDay: Bool, tooLong: Bool) {
        (x.daily > upper(x.r.h), (x.lt.map { days > $0.days }) ?? false)
    }

    private func header(_ t: String) -> some View {
        Text(t).lineLimit(2).fixedSize()
    }

    /// 两个以上单词的表头 / 标签拆成两行
    private func twoLines(_ s: String) -> String {
        guard s.count > 8 else { return s }
        if let r = s.range(of: " ") { return s.replacingCharacters(in: r, with: "\n") }
        if let r = s.range(of: "/") { return s.replacingCharacters(in: r, with: "/\n") }
        return s
    }

    /// 西语、葡语：药名单独占一整行，数字列放在下一行，表格不超出屏幕宽度
    private var compactTable: some View {
        Grid(alignment: .trailing, horizontalSpacing: 10, verticalSpacing: 4) {
            // 表头固定两行：上行名称、下行单位，按完整宽度显示，不截断
            GridRow {
                header(L("每剂", "Dose\ng"))
                header(L("每日", "Day\ng"))
                header(L("常用日量", "Usual\ng/day"))
                header(L("疗程", "Course\ng"))
                header(L("久服上限", "Max\ndays"))
                Text("")
            }
            .font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            .multilineTextAlignment(.trailing)
            Divider()
            ForEach(d.rows) { x in
                let u = upper(x.r.h)
                let f = flags(x)
                GridRow {
                    Text(hnShort(x.r.h))
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .gridCellColumns(6)
                }
                .padding(.top, 4)
                GridRow {
                    Text(num(x.r.g))
                    Text(num(x.daily))
                    Text("\(num(x.r.h.dMin))–\(num(u < x.r.h.dMax ? u : x.r.h.dMax))").foregroundStyle(.secondary)
                    Text(num(x.total))
                    Text(x.lt.map { "\($0.days)" + L(" 天", " d") } ?? "—")
                    status(f.overDay, f.tooLong).frame(maxWidth: .infinity, alignment: .trailing)
                }
                .font(.caption.monospacedDigit())
            }
        }
        .padding(.vertical, 4)
    }
}

struct IntakeRow: View {
    let x: Intake

    var body: some View {
        let p = x.v / x.lim
        let top = max(1.5, (x.lim2.map { $0 / x.lim * 1.1 }) ?? 0, min(p, 3) * 1.05)
        let overConservative = x.lim2.map { x.v > $0 } ?? false
        let color: Color = p > 1 ? .alertRed : ((overConservative || p > 0.7) ? .alertAmber : .alertOK)
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(x.k).font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(num(x.v)) / \(num(x.lim)) \(x.u) " + (x.perDose ? L("· 剂", "/ dose") : L("· 日", "/ day")))
                    .font(.caption.monospacedDigit())
            }
            GeometryReader { g in
                let w = g.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.track).frame(height: 8)
                    Capsule().fill(color).frame(width: w * CGFloat(clamp(p / top, 0, 1)), height: 8)
                    Rectangle().fill(Color.primary.opacity(0.6)).frame(width: 2, height: 14).offset(x: w * CGFloat(1 / top))
                    if let l2 = x.lim2 {
                        Rectangle().fill(Color.alertAmber).frame(width: 2, height: 14).offset(x: w * CGFloat(clamp(l2 / x.lim / top, 0, 1)))
                    }
                }
            }
            .frame(height: 14)
            Text(x.n).font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
