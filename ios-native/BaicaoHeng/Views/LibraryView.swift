import SwiftUI
import UIKit

struct LibraryView: View {
    @EnvironmentObject var st: AppState
    @State private var cat: String? = nil
    @State private var q = ""
    @State private var sel: Set<String> = []

    private var D: HerbData { DB.shared.data }

    private var current: String {
        if let cat { return cat }
        return D.presets.first { $0.n == st.s.pn }?.c ?? D.pcats.first?.k ?? ""
    }

    private var searching: Bool {
        !q.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !sel.isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                symptomChips
                if searching {
                    symptomResults
                } else {
                    categoryBrowse
                }
                Section {
                    Text(disclaimerText()).font(.footnote).foregroundStyle(.secondary)
                }
            }
            .searchable(text: $q, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: L("搜症状或方名，如：眼睛干涩、失眠", "Symptom or formula, e.g. dry eye, insomnia"))
            .navigationTitle(L("方库", "Formula Library"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { SettingsButton() }
            }
            .adBanner()
        }
    }

    private func load(_ p: Preset) {
        st.applyPreset(p)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        st.tab = .formula
    }

    // MARK: 症状

    private var symptomChips: some View {
        let detected = Set(SymptomSearch.fromQuery(q).map { $0.k })
        return Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(D.symptoms) { x in
                        Chip(text: SymptomSearch.text(x), on: sel.contains(x.k) || detected.contains(x.k)) {
                            if sel.contains(x.k) {
                                sel.remove(x.k)
                            } else if detected.contains(x.k) {
                                q = ""
                            } else {
                                sel.insert(x.k)
                            }
                        }
                    }
                }
                .padding(.vertical, 6)
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
        } header: {
            HStack {
                Text(L("按症状找方", "Find by symptom"))
                Spacer()
                if searching {
                    Button(L("清除", "Clear")) { q = ""; sel = [] }
                        .font(.caption)
                        .buttonStyle(.borderless)
                }
            }
        }
    }

    @ViewBuilder
    private var symptomResults: some View {
        let m = SymptomSearch.match(query: q, selected: sel)
        switch SymptomSearch.flag(q) {
        case .crisis?:
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("请马上联系可以帮助你的人。", "Please reach out for help now.")).font(.headline).foregroundStyle(Color.alertRed)
                    Text(L("如果你有伤害自己的念头，请立即拨打当地急救电话或心理危机干预热线，或告诉身边信任的人。草药茶帮不上这个忙。",
                           "If you are thinking about harming yourself, call your local emergency number or a crisis line right away, or tell someone you trust. Herbal tea cannot help with this."))
                        .font(.subheadline)
                }
                .listRowBackground(Color.alertRed.opacity(0.12))
            }
        case .medical?:
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("这些症状需要尽快就医。", "These symptoms need prompt medical attention.")).font(.headline).foregroundStyle(Color.alertRed)
                    Text(L("请不要依赖草药茶自行处理。", "Please do not rely on herbal tea to manage them.")).font(.subheadline)
                }
                .listRowBackground(Color.alertRed.opacity(0.12))
            }
        case nil:
            EmptyView()
        }

        Section {
            if m.results.isEmpty {
                Text(L("没有找到匹配的方子。换个说法，或从上面的症状里选。", "No matching formula. Try other words, or pick from the symptoms above."))
                    .foregroundStyle(.secondary)
            }
            let top = m.results.first?.score ?? 1
            ForEach(m.results) { r in
                Button { load(r.p) } label: {
                    SymptomResultRow(r: r, top: top, current: r.p.n == st.s.pn, showPreg: st.s.preg)
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text(m.active.isEmpty ? L("匹配结果", "Results") : L("匹配：", "Matching: ") + m.active.map(SymptomSearch.text).joined(separator: L("、", ", ")))
        } footer: {
            Text(L("匹配只依据方子的功效构成，仅供参考，不能替代医师辨证。症状持续或加重请就医。",
                   "Matching uses each formula’s action profile only. It is a reference, not a diagnosis; see a doctor if symptoms persist or worsen."))
        }
    }

    // MARK: 分类浏览

    @ViewBuilder
    private var categoryBrowse: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(D.pcats, id: \.k) { pc in
                        let n = D.presets.filter { $0.c == pc.k }.count
                        Chip(text: "\(pcatN(pc.k)) \(n)", on: pc.k == current) { cat = pc.k }
                    }
                }
                .padding(.vertical, 6)
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
        } header: {
            Text(L("按分类", "By group"))
        }

        Section {
            ForEach(D.presets.filter { $0.c == current }) { p in
                Button { load(p) } label: {
                    PresetRow(p: p, current: p.n == st.s.pn)
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text(pcatN(current))
        } footer: {
            Text(L("点一下载入到“药方”，可再调整克数和煮法。", "Tap to load it into Formula, then adjust grams and preparation."))
        }
    }
}

struct SymptomResultRow: View {
    let r: SymptomHit
    let top: Double
    let current: Bool
    let showPreg: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(pName(r.p)).font(.headline)
                    Spacer(minLength: 8)
                    Text(pcatN(r.p.c)).font(.caption).foregroundStyle(.secondary)
                }
                ProgressView(value: min(1, r.score / max(top, 0.0001)))
                    .tint(Color.brand)
                    .accessibilityLabel(L("匹配程度", "Match strength"))
                Text(matchLine).font(.caption.weight(.medium)).foregroundStyle(Color.brand)
                Text(pDesc(r.p)).font(.subheadline).foregroundStyle(.secondary)
                if showPreg && r.preg {
                    Text(L("含孕期慎用或禁用药", "Contains herbs to avoid or use with caution in pregnancy"))
                        .font(.caption).foregroundStyle(Color.alertAmber)
                }
            }
            if current {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.brand)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private var matchLine: String {
        let head = r.hit.isEmpty ? L("名称相符", "Name matches") : L("对应：", "Matches: ") + r.hit.map(SymptomSearch.text).joined(separator: L("、", ", "))
        let tags = r.tags.map { "\(tagN($0.0)) \(pct($0.1))" }.joined(separator: L("、", ", "))
        return tags.isEmpty ? head : head + " · " + tags
    }
}

struct PresetRow: View {
    let p: Preset
    let current: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(pName(p))
                        .font(.headline)
                        .foregroundStyle(p.c == "配伍反例" ? Color.alertRed : Color.primary)
                    Spacer(minLength: 8)
                    Text((p.m == "infuse" ? L("泡水", "Steep") : L("煮", "Decoct")) + " · \(num(p.mi)) " + L("分", "min"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(pDesc(p)).font(.subheadline).foregroundStyle(.secondary)
                Text(p.items.compactMap { i in DB.shared.byId[i.id].map { "\(hnShort($0)) \(num(i.g))g" } }.joined(separator: isEN ? ", " : " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if current {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.brand)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
