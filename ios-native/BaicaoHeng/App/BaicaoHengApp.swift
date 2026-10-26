import SwiftUI

@main
struct BaicaoHengApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(state)
                .environment(\.locale, Locale(identifier: state.s.lang == .en ? "en" : "zh-Hans"))
        }
    }
}

struct RootView: View {
    @EnvironmentObject var st: AppState

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
    }
}
