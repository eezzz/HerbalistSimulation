import Foundation

/// 广告与内购配置。
/// 真实 ID 只写在 project.yml 的 ADMOB_APP_ID / ADMOB_BANNER_ID / ADS_ENABLED 里，经 Info.plist 读入；
/// Debug 构建永远使用 Google 官方测试广告，避免开发时产生无效流量。
enum AdConfig {
    /// Google 官方测试 ID（https://developers.google.com/admob/ios/test-ads）
    static let testAppID = "ca-app-pub-3940256099942544~1458002511"
    static let testBannerID = "ca-app-pub-3940256099942544/2435281174"

    /// 去广告内购（非消耗型），需在 App Store Connect 建同名产品
    static let removeAdsProductID = "com.eezzz.baicaoheng.removeads"

    /// project.yml 中 ADS_ENABLED = YES 时启用广告
    static var adsEnabled: Bool {
        let v = Bundle.main.object(forInfoDictionaryKey: "BHAdsEnabled")
        if let b = v as? Bool { return b }
        if let s = v as? String { return ["YES", "TRUE", "1"].contains(s.uppercased()) }
        return false
    }

    static var bannerUnitID: String {
        #if DEBUG
        return testBannerID
        #else
        let id = (Bundle.main.object(forInfoDictionaryKey: "BHBannerUnitID") as? String) ?? ""
        return id.isEmpty ? testBannerID : id
        #endif
    }

    /// Release 构建仍在用测试 ID 时为 true（上架前应为 false）
    static var usingTestIDs: Bool {
        let app = (Bundle.main.object(forInfoDictionaryKey: "GADApplicationIdentifier") as? String) ?? ""
        return app == testAppID || bannerUnitID == testBannerID
    }
}
