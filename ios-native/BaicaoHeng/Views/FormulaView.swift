import SwiftUI

struct FormulaView: View {
    @EnvironmentObject var st: AppState
    @Environment(\.colorScheme) private var scheme
    @FocusState private var focusedHerb: String?

    var body: some View {
        let eng = st.engine
        let c = eng.compute()
        let roles = eng.roleMap(c)
        let rowsById = Dictionary(uniqueKeysWithValues: c.rows.map { ($0.h.id, $0) })

        NavigationStack {
            List {
                if let p = DB.shared.data.presets.first(where: { $0.n == st.s.pn }) {
                    Section {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pName(p)).font(.headline)
                            Text(pSrc(p) + " — " + pDesc(p)).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }

                Section(isExpanded: st.expandedBinding("formula")) {
                    if st.s.items.isEmpty {
                        Text(L("药方为空。到“方库”载入一个经典方，或在“药柜”点选药材。", "The formula is empty. Load a classic formula from Library, or pick herbs in Herbs."))
                            .foregroundStyle(.secondary)
                    }
                    ForEach(st.s.items) { it in
                        if let h = DB.shared.byId[it.id] {
                            HerbRow(item: it, h: h, row: rowsById[it.id], role: roles[it.id], upper: eng.upper(h), focused: $focusedHerb)
                        }
                    }
                    .onDelete { idx in
                        let ids = idx.map { st.s.items[$0].id }
                        ids.forEach { st.remove($0) }
                    }
                    if !st.s.items.isEmpty {
                        totals(c)
                    }
                    Text(formNoteText())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    HStack {
                        Text(L("药方", "Formula") + " · " + L("克", "grams"))
                        Spacer()
                        if !st.s.items.isEmpty {
                            Button(L("清空", "Clear"), role: .destructive) { st.clear() }
                                .font(.caption)
                                .buttonStyle(.borderless)
                        }
                    }
                }

                Section(isExpanded: st.expandedBinding("brew")) {
                    brewControls(eng, c)
                } header: {
                    Text(L("烹制", "Preparation"))
                }

                Section(isExpanded: st.expandedBinding("liquid")) {
                    liquid(eng, c)
                } header: {
                    Text(L("汤液", "The brew"))
                }

                Section(isExpanded: st.expandedBinding("dosing")) {
                    dosingControls(eng)
                } header: {
                    Text(L("服用与体质", "Dosing & constitution"))
                }
            }
            .listStyle(.sidebar)
            .navigationTitle(L("药方", "Formula"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { LangButton() }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(L("完成", "Done")) { focusedHerb = nil }
                }
            }
        }
    }

    // MARK: 合计

    private func totals(_ c: Calc) -> some View {
        let n = st.s.items.count
        let G = c.G, pd = Double(st.s.perDay), days = Double(st.s.days)
        let line = L("共 \(n) 味 · 每剂 \(num(G)) g", "\(n) herbs · \(num(G)) g per dose")
            + (st.s.perDay > 1 ? L(" · 每日 \(num(G * pd)) g", " · \(num(G * pd)) g per day") : "")
            + L(" · 连服 \(st.s.days) 天共 \(num(G * pd * days)) g", " · \(num(G * pd * days)) g over \(st.s.days) days")
        return VStack(alignment: .leading, spacing: 2) {
            Text(line).font(.footnote.monospacedDigit())
            Text(L("估算溶入汤液约 \(num(c.exTotal * 0.3)) g 可溶物", "≈ \(num(c.exTotal * 0.3)) g of solids dissolved"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: 烹制

    @ViewBuilder
    private func brewControls(_ eng: Engine, _ c: Calc) -> some View {
        Picker(L("方式", "Method"), selection: Binding(get: { st.s.method }, set: { st.setMethod($0) })) {
            Text(L("泡水", "Steep")).tag("infuse")
            Text(L("煮", "Decoct")).tag("boil")
        }
        .pickerStyle(.segmented)
        Text(st.s.method == "infuse"
             ? L("适合花、叶、薄片类；根茎溶出有限", "Suits flowers, leaves and thin slices; roots extract poorly")
             : L("适合根茎、果实、种子；芳香药宜后下", "Suits roots, fruits and seeds; add aromatic herbs last"))
            .font(.caption)
            .foregroundStyle(.secondary)

        SliderRow(title: L("水量", "Water"), value: $st.s.water, range: 150...1500, step: 50, unit: "ml")
        if st.s.method == "infuse" {
            SliderRow(title: L("水温", "Water temp"), value: $st.s.temp, range: 80...100, step: 5, unit: "°C")
        }
        SliderRow(title: st.s.method == "infuse" ? L("焖泡时间", "Steeping time") : L("文火煎煮（沸后计）", "Simmer time (after boiling)"),
                  value: $st.s.minutes, range: st.minuteRange(), step: 1, unit: L("分钟", "min"))
        if st.s.method == "boil" {
            Toggle(L("煎前冷水浸泡 30 分钟", "Soak in cold water 30 min first"), isOn: $st.s.soak)
        }
        let hint = eng.waterHint(c)
        if !hint.isEmpty {
            Text(hint).font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: 汤液

    private func liquid(_ eng: Engine, _ c: Calc) -> some View {
        let fill = st.s.water > 0 ? Double(c.out) / st.s.water : 0
        return HStack(alignment: .center, spacing: 16) {
            BrewCup(rgb: eng.brewRGB(c, dark: scheme == .dark), fill: fill)
            VStack(alignment: .leading, spacing: 6) {
                stat(L("出汤量", "Yield"), "\(c.out) ml" + (st.s.method == "boil" ? L("（蒸发约 \(Int(c.evap.rounded())) ml）", " (≈\(Int(c.evap.rounded())) ml evaporated)") : ""))
                stat(L("浓度", "Strength"), eng.concLabel(c.conc) + " · \(num(c.conc)) g/100ml")
                stat(L("口感", "Taste"), c.rows.isEmpty ? "—" : eng.tasteText(c))
            }
        }
        .padding(.vertical, 4)
    }

    private func stat(_ k: String, _ v: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(k).font(.caption).foregroundStyle(.secondary).frame(width: isEN ? 64 : 44, alignment: .leading)
            Text(v).font(.subheadline)
        }
    }

    // MARK: 服用

    @ViewBuilder
    private func dosingControls(_ eng: Engine) -> some View {
        Picker(L("每日剂数", "Doses per day"), selection: $st.s.perDay) {
            ForEach(1...3, id: \.self) { n in
                Text(L("每日 \(n) 剂", "\(n) / day")).tag(n)
            }
        }
        SliderRow(title: L("连续服用", "Course length"),
                  value: Binding(get: { Double(st.s.days) }, set: { st.s.days = Int($0) }),
                  range: 1...90, step: 1, unit: L("天", "days"))
        VStack(alignment: .leading, spacing: 4) {
            SliderRow(title: L("体重", "Body weight"), value: $st.s.weight, range: 30...120, step: 1, unit: "kg")
            let wh = eng.weightHint()
            Text(wh.text)
                .font(.caption)
                .foregroundStyle(st.s.weight < 50 ? Color.alertAmber : Color.secondary)
                .opacity(wh.idle ? 0.7 : 1)
        }
        Picker(L("体质", "Constitution"), selection: $st.s.body) {
            ForEach(DB.shared.data.bodies, id: \.k) { b in
                Text("\(bodyN(b.k)) · \(bodyD(b.k))").tag(b.k)
            }
        }
        .pickerStyle(.navigationLink)
        Toggle(L("孕期 / 备孕", "Pregnant / trying to conceive"), isOn: $st.s.preg)
    }
}

struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title).font(.subheadline)
                Spacer()
                Text("\(num(value)) \(unit)").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
            }
            Slider(value: Binding(get: { clamp(value, range.lowerBound, range.upperBound) }, set: { value = $0 }),
                   in: range, step: step)
                .accessibilityLabel(title)
                .accessibilityValue("\(num(value)) \(unit)")
        }
    }
}

struct HerbRow: View {
    @EnvironmentObject var st: AppState
    let item: Item
    let h: Herb
    let row: Row?
    let role: String?
    let upper: Double
    var focused: FocusState<String?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Circle().fill(natColor(h.t)).frame(width: 8, height: 8)
                Text(hn(h)).font(.headline)
                if let role {
                    Text(roleN(role))
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .foregroundStyle(role == "君" ? Color.fire : Color.secondary)
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(role == "君" ? Color.fire : Color.gray.opacity(0.5)))
                }
                Spacer()
                Button { st.remove(h.id) } label: {
                    Image(systemName: "xmark.circle.fill").font(.title3).foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(L("移除", "Remove") + " " + hn(h))
            }
            Text("\(natT(h.tl)) · \(flavT(h.f)) · " + (isEN ? "enters \(merT(h))" : "归\(h.m)经") + " · \(partN(h.p))")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(L("规格：", "Form: ") + hform(h))
                .font(.caption)
                .foregroundStyle(h.formLv == 2 ? Color.alertRed : (h.formLv == 1 ? Color.alertAmber : Color.secondary))

            let flags = flagButtons()
            if !flags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(flags, id: \.label) { f in
                        if let key = f.key {
                            Button { st.toggleFlag(h.id, key) } label: { flagLabel(f.label, on: item.fl[keyPath: key]) }
                                .buttonStyle(.borderless)
                        } else {
                            flagLabel(f.label, on: false, note: true)
                        }
                    }
                }
            }

            HStack(alignment: .center, spacing: 12) {
                gramStepper
                DoseBar(h: h, g: item.g, upper: upper)
            }

            if let row {
                let total = st.engine.eTotal(row.e)
                Text((st.s.method == "boil" ? L("头煎", "1st boil") : L("首泡", "1st steep")) + " \(pct(row.e)) · " + L("合计", "total") + " \(pct(total))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var gramStepper: some View {
        HStack(spacing: 0) {
            Button { st.step(h.id, -1) } label: {
                Image(systemName: "minus").frame(width: 40, height: 40)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(L("减 1 克", "Minus 1 g"))
            TextField("0", value: Binding(get: { item.g }, set: { st.setGram(h.id, $0) }), format: .number.precision(.fractionLength(0...1)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.body.monospacedDigit())
                .frame(width: 52)
                .focused(focused, equals: h.id)
                .accessibilityLabel(hn(h) + " " + L("克数", "grams"))
            Text("g").font(.caption).foregroundStyle(.secondary).padding(.leading, 2)
            Button { st.step(h.id, 1) } label: {
                Image(systemName: "plus").frame(width: 40, height: 40)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(L("加 1 克", "Plus 1 g"))
        }
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.track.opacity(0.6)))
    }

    private struct FlagSpec {
        let label: String
        let key: WritableKeyPath<Flags, Bool>?
    }

    private func flagButtons() -> [FlagSpec] {
        var out: [FlagSpec] = []
        let boil = st.s.method == "boil"
        for k in h.sp {
            switch k {
            case "late" where boil: out.append(FlagSpec(label: L("后下", "Add last"), key: \.late))
            case "first" where boil: out.append(FlagSpec(label: L("先煎", "Cook first"), key: \.first))
            case "crush": out.append(FlagSpec(label: h.id == "dazao" ? L("掰开", "Split open") : L("捣碎", "Crush"), key: \.crush))
            case "melt": out.append(FlagSpec(label: L("烊化", "Melt separately"), key: \.melt))
            case "honey": out.append(FlagSpec(label: L("温水调服", "Stir in when warm"), key: \.honey))
            case "separate": out.append(FlagSpec(label: L("宜另煎兑服", "Best simmered separately"), key: nil))
            case "powder": out.append(FlagSpec(label: L("宜研粉冲服 1–3g", "Best taken as powder, 1–3 g"), key: nil))
            case "wrap": out.append(FlagSpec(label: L("包煎", "Cook in a bag"), key: nil))
            default: break
            }
        }
        return out
    }

    private func flagLabel(_ text: String, on: Bool, note: Bool = false) -> some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 10)
            .frame(minHeight: 30)
            .foregroundStyle(on ? Color.brand : Color.secondary)
            .overlay(
                Capsule().stroke(on ? Color.brand : Color.gray.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: on || note ? [] : [3, 2]))
            )
            .accessibilityAddTraits(on ? .isSelected : [])
    }
}
