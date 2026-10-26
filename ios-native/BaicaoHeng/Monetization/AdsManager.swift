import SwiftUI
import UIKit
import AppTrackingTransparency
import GoogleMobileAds
import UserMessagingPlatform

/// 广告启动流程：Google 同意弹窗（UMP，欧盟等地区必需）→ 苹果“允许跟踪”授权（ATT）→ 启动广告 SDK。
/// 用户拒绝跟踪时 SDK 自动展示非个性化广告。
/// 本文件使用 Google Mobile Ads SDK 12.x 与 UMP 3.x 的 Swift 命名（BannerView、ConsentInformation 等）。
@MainActor
final class AdsManager: ObservableObject {
    @Published private(set) var canRequestAds = false
    @Published private(set) var privacyOptionsRequired = false

    private var flowStarted = false
    private var sdkStarted = false

    func start() {
        guard AdConfig.adsEnabled, !flowStarted else { return }
        flowStarted = true

        // 之前已取得同意时可直接启动，不必等待本次更新
        if ConsentInformation.shared.canRequestAds { afterConsent() }

        ConsentInformation.shared.requestConsentInfoUpdate(with: RequestParameters()) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if let vc = UIApplication.shared.topViewController {
                    ConsentForm.loadAndPresentIfRequired(from: vc) { _ in
                        Task { @MainActor in self.afterConsent() }
                    }
                } else {
                    self.afterConsent()
                }
            }
        }
    }

    private func afterConsent() {
        privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
        guard ConsentInformation.shared.canRequestAds, !sdkStarted else { return }
        sdkStarted = true
        requestTrackingIfNeeded { [weak self] in
            MobileAds.shared.start(completionHandler: nil)
            self?.canRequestAds = true
        }
    }

    private func requestTrackingIfNeeded(_ done: @escaping @MainActor () -> Void) {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { done(); return }
        ATTrackingManager.requestTrackingAuthorization { _ in
            Task { @MainActor in done() }
        }
    }

    /// 让用户修改广告同意选项（欧盟等地区要求提供入口）
    func presentPrivacyOptions() {
        guard let vc = UIApplication.shared.topViewController else { return }
        ConsentForm.presentPrivacyOptionsForm(from: vc) { [weak self] _ in
            Task { @MainActor in
                self?.privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
            }
        }
    }
}

extension UIApplication {
    var topViewController: UIViewController? {
        let scene = connectedScenes.compactMap { $0 as? UIWindowScene }.first { $0.activationState == .foregroundActive }
            ?? connectedScenes.compactMap { $0 as? UIWindowScene }.first
        var vc = scene?.windows.first { $0.isKeyWindow }?.rootViewController ?? scene?.windows.first?.rootViewController
        while let presented = vc?.presentedViewController { vc = presented }
        return vc
    }

    var screenWidth: CGFloat {
        (connectedScenes.compactMap { $0 as? UIWindowScene }.first?.screen.bounds.width) ?? 375
    }
}

// MARK: - 横幅广告

/// 自适应锚定横幅（底部）
struct BannerAdView: UIViewRepresentable {
    let adUnitID: String
    let size: AdSize

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: size)
        banner.adUnitID = adUnitID
        banner.rootViewController = UIApplication.shared.topViewController
        banner.load(Request())
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}
}

/// 只有在：构建启用广告、用户未购买去广告、已取得可请求广告的同意 时才显示
struct AdBannerSlot: View {
    @EnvironmentObject var ads: AdsManager
    @EnvironmentObject var store: PurchaseStore

    var body: some View {
        if AdConfig.adsEnabled && !store.adsRemoved && ads.canRequestAds {
            let size = currentOrientationAnchoredAdaptiveBanner(width: UIApplication.shared.screenWidth)
            BannerAdView(adUnitID: AdConfig.bannerUnitID, size: size)
                .frame(height: size.size.height)
                .frame(maxWidth: .infinity)
                .background(.bar)
                .accessibilityLabel(L("广告", "Advertisement"))
        }
    }
}

extension View {
    /// 在页面底部（标签栏上方）放一条横幅广告
    func adBanner() -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) { AdBannerSlot() }
    }
}
