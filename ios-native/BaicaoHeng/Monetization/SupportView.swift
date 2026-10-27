import SwiftUI
import UIKit

/// 设置与支持：去广告内购、恢复购买、广告隐私选项、免责声明
struct SupportView: View {
    @EnvironmentObject var st: AppState
    @EnvironmentObject var ads: AdsManager
    @EnvironmentObject var store: PurchaseStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker(selection: $st.s.lang) {
                        ForEach(Lang.allCases, id: \.self) { l in
                            Text(l.nativeName).tag(l)
                        }
                    } label: {
                        Text(L("语言", "Language"))
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text(L("语言", "Language"))
                }

                if AdConfig.adsEnabled {
                    Section {
                        if store.adsRemoved {
                            Label(L("已去除广告", "Ads removed"), systemImage: "checkmark.seal.fill")
                                .foregroundStyle(Color.alertOK)
                        } else {
                            Button {
                                Task { await store.purchase() }
                            } label: {
                                HStack {
                                    Label(L("去除广告", "Remove ads"), systemImage: "nosign")
                                    Spacer()
                                    if store.busy {
                                        ProgressView()
                                    } else if let p = store.product {
                                        Text(p.displayPrice).monospacedDigit()
                                    } else {
                                        Text(L("暂不可用", "Unavailable")).foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .disabled(store.product == nil || store.busy)
                        }
                        if let id = store.purchaseID {
                            LabeledContent(L("购买编号", "Purchase ID")) {
                                Text(id).monospacedDigit().textSelection(.enabled)
                            }
                            .contextMenu {
                                Button { UIPasteboard.general.string = id } label: {
                                    Label(L("复制", "Copy"), systemImage: "doc.on.doc")
                                }
                            }
                        }
                        Button(L("恢复购买", "Restore purchases")) {
                            Task { await store.restore() }
                        }
                        .disabled(store.busy)
                    } header: {
                        Text(L("广告", "Ads"))
                    } footer: {
                        Text(L("一次购买，永久去除广告；同一 Apple ID 的其他设备可用“恢复购买”。", "One purchase removes ads for good; use Restore purchases on other devices with the same Apple ID."))
                    }

                    if ads.privacyOptionsRequired {
                        Section {
                            Button(L("广告隐私选项", "Ad privacy choices")) { ads.presentPrivacyOptions() }
                        }
                    }

                    #if DEBUG
                    Section {
                        Text(L("调试构建：广告使用 Google 测试 ID，内购使用本地 StoreKit 配置，不会产生真实收入或扣费。",
                               "Debug build: ads use Google test IDs and purchases use the local StoreKit configuration; no real revenue or charges."))
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    #endif
                }

                if let url = supportMailURL {
                    Section {
                        Link(destination: url) {
                            Label(L("联系客服", "Contact support"), systemImage: "envelope")
                        }
                    } footer: {
                        Text(L("购买或去广告有问题时，邮件会自动附上版本号和购买编号。", "For purchase or ad-removal issues; the email includes your app version and purchase ID."))
                    }
                }

                Section {
                    Text(disclaimerText()).font(.footnote).foregroundStyle(.secondary)
                    LabeledContent(L("版本", "Version"), value: appVersion)
                }
            }
            .navigationTitle(L("设置", "Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button(L("完成", "Done")) { dismiss() } }
            }
            .alert(store.message ?? "", isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) {
                Button(L("好", "OK"), role: .cancel) {}
            }
        }
    }

    /// mailto 链接：主题带版本号，正文带购买编号，方便核对订单
    private var supportMailURL: URL? {
        let to = AdConfig.supportEmail
        guard !to.isEmpty else { return nil }
        var c = URLComponents()
        c.scheme = "mailto"
        c.path = to
        c.queryItems = [
            URLQueryItem(name: "subject", value: L("百草衡 客服", "Support request") + " (\(appVersion))"),
            URLQueryItem(name: "body", value: "\n\n—\n" + L("购买编号：", "Purchase ID: ") + (store.purchaseID ?? "-") + "\niOS " + UIDevice.current.systemVersion),
        ]
        return c.url
    }

    private var appVersion: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(v) (\(b))"
    }
}

/// 工具栏上的“设置”按钮
struct SettingsButton: View {
    @EnvironmentObject var st: AppState
    var body: some View {
        Button { st.showSettings = true } label: { Image(systemName: "gearshape") }
            .accessibilityLabel(L("设置", "Settings"))
    }
}
