import SwiftUI

@main
struct BaicaoHengApp: App {
    @StateObject private var state = AppState()
    @StateObject private var ads = AdsManager()
    @StateObject private var store = PurchaseStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(state)
                .environmentObject(ads)
                .environmentObject(store)
                .environment(\.locale, Locale(identifier: state.s.lang == .en ? "en" : "zh-Hans"))
        }
    }
}

struct RootView: View {
    @EnvironmentObject var st: AppState
    @EnvironmentObject var ads: AdsManager
    @EnvironmentObject var store: PurchaseStore

    var body: some View {
        TabView(selection: $st.tab) {
            LibraryView()
                .tabItem { Label(L("方库", "Library"), systemImage: "books.vertical") }
                .tag(AppTab.library)
            CabinetView()
                .tabItem { Label(L("药柜", "Herbs"), systemImage: "square.grid.3x3") }
                .tag(AppTab.cabinet)
            FormulaView()
                .tabItem { Label(L("药方", "Formula"), systemImage: "list.bullet.rectangle") }
                .badge(st.s.items.count)
                .tag(AppTab.formula)
            AnalysisView()
                .tabItem { Label(L("分析", "Analysis"), systemImage: "chart.pie") }
                .tag(AppTab.analysis)
        }
        .tint(Color.brand)
        // 选择器、搜索框提示、标签栏等系统控件会缓存文字；切换语言时整体重建界面，保证全部换成新语言
        .id(st.s.lang)
        .task {
            // 买过去广告的用户不再弹广告同意 / 跟踪授权
            if !store.adsRemoved { ads.start() }
        }
    }
}
