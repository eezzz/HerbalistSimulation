import SwiftUI
import UIKit

struct CabinetView: View {
    @EnvironmentObject var st: AppState
    @State private var q = ""
    @State private var cat = "全部"
    @State private var detail: Herb? = nil

    private var list: [Herb] {
        let q = self.q.trimmingCharacters(in: .whitespaces).lowercased()
        return DB.shared.data.herbs.filter { h in
            let inCat = cat == "全部" || (cat == "西方" ? h.west > 0 : h.cat == cat)
            guard inCat else { return false }
            if q.isEmpty { return true }
            if h.n.contains(q) || h.py.contains(q) || h.g.contains(q) || h.id.contains(q) { return true }
            if h.fx.contains(where: { kv in
                guard let t = DB.shared.tags[kv.k] else { return kv.k.contains(q) }
                return kv.k.contains(q) || t.enName.lowercased().contains(q) || t.enFit.lowercased().contains(q)
            }) { return true }
            if let e = EH(h) {
                if e.n.lowercased().contains(q) || (e.g ?? "").lowercased().contains(q) { return true }
            }
            return false
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(DB.shared.data.cats, id: \.k) { c in
                                Chip(text: catN(c.k), on: c.k == cat) { cat = c.k }
                            }
                        }
                        .padding(.horizontal)
                    }

                    let items = list
                    if items.isEmpty {
                        Text(L("没有匹配的药材", "No matching herbs"))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: isEN ? 112 : 92), spacing: 8)], spacing: 8) {
                            ForEach(items) { h in
                                DrawerTile(h: h, added: st.contains(h.id)) {
                                    st.toggleHerb(h.id)
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }
                                .contextMenu {
                                    Button { detail = h } label: { Label(L("查看药材档案", "View profile"), systemImage: "info.circle") }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    HStack(spacing: 14) {
                        legendDot(.cold, L("寒凉", "Cold / cool"))
                        legendDot(.gray, L("平", "Neutral"))
                        legendDot(.hot, L("温热", "Warm / hot"))
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    Text(L("点一下加入或移出药方；长按查看药材档案。", "Tap to add or remove; press and hold to view the profile."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                    Text(formNoteText())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.bottom, 16)
                }
                .padding(.top, 8)
            }
            .searchable(text: $q, prompt: L("药名、拼音或功效，如：明目、安神", "Name, pinyin or action, e.g. sleep, eyes"))
            .navigationTitle(L("药柜", "Herb Cabinet"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { SettingsButton() }
                ToolbarItem(placement: .topBarTrailing) {
                    Text(L("\(list.count) / \(DB.shared.data.herbs.count) 味", "\(list.count) / \(DB.shared.data.herbs.count)"))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .sheet(item: $detail) { h in HerbDetailView(h: h) }
        }
    }

    private func legendDot(_ c: Color, _ t: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(c).frame(width: 8, height: 8)
            Text(t)
        }
    }
}

struct DrawerTile: View {
    let h: Herb
    let added: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .top) {
                    Text(hnShort(h))
                        .font(isEN ? .subheadline.weight(.semibold) : .headline)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 2)
                    Image(systemName: added ? "checkmark.circle.fill" : "circle.fill")
                        .font(.system(size: added ? 14 : 8))
                        .foregroundStyle(added ? Color.brand : natColor(h.t))
                }
                Text(isEN ? "\(hpy(h)) · \(natT(h.tl))" : "\(h.tl) · \(h.f)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 8).fill(added ? Color.brandSoft : Color(.secondarySystemGroupedBackground)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(added ? Color.brand : Color.gray.opacity(0.25), lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(hn(h) + ", " + natT(h.tl))
        .accessibilityAddTraits(added ? .isSelected : [])
    }
}

struct HerbDetailView: View {
    let h: Herb
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent(L("四气", "Nature"), value: natT(h.tl))
                    LabeledContent(L("五味", "Flavor"), value: flavT(h.f))
                    LabeledContent(L("归经", "Meridians"), value: merT(h))
                    LabeledContent(L("常用日量", "Usual daily dose"), value: "\(num(h.dMin))–\(num(h.dMax)) g")
                    LabeledContent(L("部位", "Part"), value: partN(h.p))
                }
                Section(L("规格", "Form")) {
                    Text(hform(h))
                        .foregroundStyle(h.formLv == 2 ? Color.alertRed : (h.formLv == 1 ? Color.alertAmber : Color.primary))
                }
                Section(L("功效", "Actions")) { Text(hg(h)) }
                Section(L("主要成分", "Constituents")) { Text(hc(h)) }
                Section(L("注意", "Cautions")) {
                    Text(hw(h))
                    if !hnote(h).isEmpty { Text(hnote(h)).foregroundStyle(.secondary) }
                }
                if !hix(h).isEmpty {
                    Section(L("药物相互作用", "Drug interactions")) {
                        ForEach(hix(h), id: \.self) { Text($0) }
                    }
                }
                if let w = westNote(h) {
                    Section { Text(w).font(.footnote).foregroundStyle(.secondary) }
                }
            }
            .navigationTitle(hn(h))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L("完成", "Done")) { dismiss() } } }
        }
    }
}
