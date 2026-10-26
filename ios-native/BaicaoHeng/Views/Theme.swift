import SwiftUI
import UIKit

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}

extension Color {
    /// 浅色 / 深色模式各一种颜色
    static func dyn(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
    }

    init(hexString: String) {
        let (r, g, b) = hexRGB(hexString)
        self.init(red: r, green: g, blue: b)
    }

    static let brand = dyn(0x2D5B57, 0x7DB1A8)
    static let brandSoft = dyn(0xD5E3DE, 0x223532)
    static let wood = dyn(0x4C7A37, 0x86B86E)
    static let fire = dyn(0xB3452F, 0xE27C63)
    static let earth = dyn(0xA9832A, 0xD6B25A)
    static let metal = dyn(0x7B838A, 0xB8BEC3)
    static let waterEl = dyn(0x2D4F77, 0x7FA6D4)
    static let cold = dyn(0x3F6E9A, 0x7FAEDB)
    static let hot = dyn(0xB5462E, 0xE3826A)
    static let alertRed = dyn(0xA23A2A, 0xE58574)
    static let alertAmber = dyn(0x8A5E0E, 0xD9AB52)
    static let alertInfo = dyn(0x35597A, 0x8BB2D6)
    static let alertOK = dyn(0x3F6E3A, 0x8FC082)
    static let track = Color.gray.opacity(0.18)
}

func elColor(_ e: String) -> Color {
    switch e {
    case "木": return .wood
    case "火": return .fire
    case "土": return .earth
    case "金": return .metal
    default: return .waterEl
    }
}

func natColor(_ t: Double) -> Color {
    if t < -0.2 { return .cold }
    if t > 0.2 { return .hot }
    return .gray
}

func levelColor(_ lv: Level) -> Color {
    switch lv {
    case .red: return .alertRed
    case .amber: return .alertAmber
    case .info: return .alertInfo
    case .ok: return .alertOK
    }
}

/// Markdown 文本（支持 **加粗**）
func md(_ s: String) -> Text {
    if let a = try? AttributedString(markdown: s, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
        return Text(a)
    }
    return Text(s)
}
