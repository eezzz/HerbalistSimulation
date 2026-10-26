import SwiftUI
import UIKit

struct LibraryView: View {
    @EnvironmentObject var st: AppState
    @State private var cat: String? = nil

    private var D: HerbData { DB.shared.data }

    private var current: String {
        if let cat { return cat }
        return D.presets.first { $0.n == st.s.pn }?.c ?? D.pcats.first?.k ?? ""
    }

    var body: some View {
        NavigationStack {
            List {
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
                }

                Section {
                    ForEach(D.presets.filter { $0.c == current }) { p in
                        Button {
                            st.applyPreset(p)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            st.tab = .formula
                        } label: {
                            PresetRow(p: p, current: p.n == st.s.pn)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text(pcatN(current))
                } footer: {
                    Text(L("点一下载入到“药方”，可再调整克数和煮法。", "Tap to load it into Formula, then adjust grams and preparation."))
                }

                Section {
                    Text(disclaimerText()).font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle(L("方库", "Formula Library"))
            .toolbar { ToolbarItem(placement: .topBarTrailing) { LangButton() } }
        }
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
