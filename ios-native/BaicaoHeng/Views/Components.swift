import SwiftUI

// MARK: - 通用小组件

struct Chip: View {
    let text: String
    let on: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.subheadline)
                .padding(.horizontal, 14)
                .frame(minHeight: 36)
                .foregroundStyle(on ? Color.white : Color.primary)
                .background(Capsule().fill(on ? Color.brand : Color.track))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// 自动换行排列
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, widest: CGFloat = 0
        for v in subviews {
            let sz = v.sizeThatFits(.unspecified)
            if x > 0 && x + sz.width > maxW { x = 0; y += rowH + spacing; rowH = 0 }
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: proposal.width ?? widest, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for v in subviews {
            let sz = v.sizeThatFits(.unspecified)
            if x > bounds.minX && x + sz.width > bounds.maxX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(sz))
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
        }
    }
}

/// 横向比例条
struct BarList: View {
    let items: [(String, Double)]
    let color: (String) -> Color
    let label: (String) -> String

    var body: some View {
        let mx = max(items.map { $0.1 }.max() ?? 0, 0.0001)
        VStack(spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(spacing: 8) {
                    Text(label(item.0))
                        .font(.subheadline)
                        .lineLimit(2)
                        .frame(width: isEN ? 112 : 56, alignment: .leading)
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.track)
                            Capsule().fill(color(item.0)).frame(width: g.size.width * item.1 / mx)
                        }
                    }
                    .frame(height: 8)
                    Text(pct(item.1))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct AlertRow: View {
    let a: AlertItem
    var body: some View {
        Group {
            if isLongLang {
                // 西语、葡语的标签较长，单独一行，说明文字用满整行宽度
                VStack(alignment: .leading, spacing: 4) {
                    tag
                    Text(a.t).font(.subheadline)
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    tag.fixedSize()
                    Text(a.t).font(.subheadline)
                }
            }
        }
        .padding(.vertical, 6)
        .listRowBackground(levelColor(a.lv).opacity(0.12))
    }

    private var tag: some View {
        Text(a.ty)
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 4).fill(levelColor(a.lv)))
    }
}

struct BulletList: View {
    let items: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, s in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("•").foregroundStyle(.secondary)
                    md(s)
                }
                .font(.subheadline)
            }
        }
    }
}

struct SubHeading: View {
    let text: String
    var body: some View {
        Text(text).font(.caption.weight(.semibold)).foregroundStyle(.secondary).textCase(nil)
    }
}

/// 常用量刻度条：绿色为常用量，橙色刻度为低体重收紧后的上限
struct DoseBar: View {
    let h: Herb
    let g: Double
    let upper: Double

    var body: some View {
        let top = max(h.dMax * 1.6, g * 1.05)
        VStack(alignment: .leading, spacing: 3) {
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.track).frame(height: 6)
                    Capsule().fill(Color.alertOK.opacity(0.45))
                        .frame(width: w * (h.dMax - h.dMin) / top, height: 6)
                        .offset(x: w * h.dMin / top)
                    if upper < h.dMax {
                        Rectangle().fill(Color.alertAmber).frame(width: 2, height: 10).offset(x: w * upper / top)
                    }
                    RoundedRectangle(cornerRadius: 1)
                        .fill(g > upper ? Color.alertRed : Color.primary)
                        .frame(width: 3, height: 14)
                        .offset(x: min(w - 3, w * g / top))
                }
                .frame(height: 14)
            }
            .frame(height: 14)
            Text(L("常用量", "Usual dose") + " \(num(h.dMin))–\(num(h.dMax)) g" + (upper < h.dMax ? L(" · 宜 ≤ \(num(upper)) g", " · keep ≤ \(num(upper)) g") : ""))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

/// 寒热刻度
struct NatureGauge: View {
    let T: Double
    let ticks: [Double]

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                let w = geo.size.width
                let x: (Double) -> CGFloat = { CGFloat((clamp($0, -3, 3) + 3) / 6) * w }
                ZStack(alignment: .topLeading) {
                    Capsule()
                        .fill(LinearGradient(colors: [.cold, Color.track, .hot], startPoint: .leading, endPoint: .trailing))
                        .frame(height: 8)
                        .offset(y: 12)
                    ForEach(Array(ticks.enumerated()), id: \.offset) { _, t in
                        Rectangle().fill(Color.secondary.opacity(0.6)).frame(width: 2, height: 14).offset(x: x(t) - 1, y: 9)
                    }
                    Image(systemName: "arrowtriangle.down.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.primary)
                        .offset(x: x(T) - 6, y: -2)
                }
            }
            .frame(height: 26)
            HStack {
                ForEach([L("大寒", "V. cold"), L("寒", "Cold"), L("凉", "Cool"), L("平", "Neutral"), L("温", "Warm"), L("热", "Hot"), L("大热", "V. hot")], id: \.self) { s in
                    if isLongLang {
                        // 每个单词一行、必要时缩小字号，避免单词从中间断开
                        VStack(spacing: 0) {
                            ForEach(s.split(separator: " ").map(String.init), id: \.self) { w in
                                Text(w).lineLimit(1).minimumScaleFactor(0.6)
                            }
                        }
                        .font(.caption2).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                    } else {
                        Text(s).font(.caption2).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }
}

/// 五行雷达图：外环顺时针为相生，虚线五角为相克
struct RadarChart: View {
    let el: OrderedSum
    private let size: CGFloat = 250
    private let R: CGFloat = 84

    private func pt(_ i: Int, _ r: CGFloat) -> CGPoint {
        let a = -Double.pi / 2 + Double(i) * 2 * Double.pi / 5
        return CGPoint(x: size / 2 + r * CGFloat(cos(a)), y: size / 2 + r * CGFloat(sin(a)))
    }

    var body: some View {
        let mx = max(0.4, EL.map { el[$0] }.max() ?? 0.4)
        ZStack {
            Canvas { ctx, _ in
                for f in [1.0, 0.66, 0.33] as [CGFloat] {
                    var p = Path()
                    for i in 0..<5 {
                        if i == 0 { p.move(to: pt(i, R * f)) } else { p.addLine(to: pt(i, R * f)) }
                    }
                    p.closeSubpath()
                    ctx.stroke(p, with: .color(Color.gray.opacity(f == 1 ? 0.5 : 0.25)), lineWidth: 1)
                }
                var star = Path()
                for (j, i) in [0, 2, 4, 1, 3, 0].enumerated() {
                    if j == 0 { star.move(to: pt(i, R)) } else { star.addLine(to: pt(i, R)) }
                }
                ctx.stroke(star, with: .color(Color.gray.opacity(0.35)), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                var poly = Path()
                for (i, e) in EL.enumerated() {
                    let p = pt(i, R * CGFloat(el[e] / mx))
                    if i == 0 { poly.move(to: p) } else { poly.addLine(to: p) }
                }
                poly.closeSubpath()
                ctx.fill(poly, with: .color(Color.brand.opacity(0.18)))
                ctx.stroke(poly, with: .color(Color.brand), lineWidth: 2)
                for (i, e) in EL.enumerated() {
                    let p = pt(i, R * CGFloat(el[e] / mx))
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8)), with: .color(elColor(e)))
                }
            }
            ForEach(Array(EL.enumerated()), id: \.offset) { i, e in
                VStack(spacing: 0) {
                    Text(elN(e)).font(.caption.weight(.bold)).foregroundStyle(elColor(e))
                    Text(pct(el[e])).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                }
                .position(pt(i, R + 26))
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(EL.map { "\(elN($0)) \(pct(el[$0]))" }.joined(separator: ", "))
    }
}

/// 汤液示意
struct BrewCup: View {
    let rgb: (Double, Double, Double)
    let fill: Double   // 0–1

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 10).fill(Color.track.opacity(0.4))
            Rectangle()
                .fill(Color(red: rgb.0, green: rgb.1, blue: rgb.2))
                .frame(height: 72 * CGFloat(clamp(fill, 0.08, 1)))
            RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.6), lineWidth: 2)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .frame(width: 64, height: 72)
        .accessibilityHidden(true)
    }
}
