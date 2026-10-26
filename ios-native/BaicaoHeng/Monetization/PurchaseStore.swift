import Foundation
import StoreKit

/// 去广告内购（StoreKit 2，非消耗型）。
/// 本地调试用 ios-native/Products.storekit（Xcode 运行时自动加载，无需 App Store Connect）。
@MainActor
final class PurchaseStore: ObservableObject {
    @Published private(set) var product: Product?
    @Published private(set) var adsRemoved: Bool
    @Published private(set) var busy = false
    @Published var message: String?

    private static let cacheKey = "baicaoheng.adsRemoved"
    private var updates: Task<Void, Never>?

    init() {
        adsRemoved = UserDefaults.standard.bool(forKey: Self.cacheKey)
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(result)
            }
        }
        Task {
            await refreshEntitlements()
            await loadProduct()
        }
    }

    func loadProduct() async {
        do {
            product = try await Product.products(for: [AdConfig.removeAdsProductID]).first
        } catch {
            product = nil
        }
    }

    func purchase() async {
        guard let product, !busy else { return }
        busy = true
        defer { busy = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                if case .verified(let t) = verification {
                    setRemoved(true)
                    await t.finish()
                    message = L("已去除广告，感谢支持！", "Ads removed. Thank you for your support!")
                } else {
                    message = L("购买验证失败，请稍后再试或恢复购买。", "The purchase could not be verified. Try again later or restore purchases.")
                }
            case .pending:
                message = L("购买待确认（如需家长同意），确认后会自动生效。", "The purchase is pending approval and will apply automatically once approved.")
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            message = L("购买未完成：", "Purchase not completed: ") + error.localizedDescription
        }
    }

    func restore() async {
        busy = true
        defer { busy = false }
        do {
            try await AppStore.sync()
        } catch {
            message = L("恢复失败：", "Restore failed: ") + error.localizedDescription
            return
        }
        await refreshEntitlements()
        message = adsRemoved
            ? L("已恢复去广告。", "Ad removal restored.")
            : L("这个 Apple ID 下没有找到去广告购买记录。", "No ad-removal purchase found for this Apple ID.")
    }

    func refreshEntitlements() async {
        var owned = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result, t.productID == AdConfig.removeAdsProductID, t.revocationDate == nil {
                owned = true
            }
        }
        setRemoved(owned)
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let t) = result else { return }
        if t.productID == AdConfig.removeAdsProductID { setRemoved(t.revocationDate == nil) }
        await t.finish()
    }

    private func setRemoved(_ v: Bool) {
        adsRemoved = v
        UserDefaults.standard.set(v, forKey: Self.cacheKey)
    }
}
