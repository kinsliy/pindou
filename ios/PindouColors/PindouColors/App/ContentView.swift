import SwiftUI

// ============================================
// ContentView - 应用主界面
// 只保留 3 个顶部 Tab：豆仓、图纸册、设置
// 原因：灵感库、记录、我的暂未实现，用户希望精简导航
// ============================================

struct ContentView: View {
    var body: some View {
        TabView {
            // 豆仓 - 颜色仓库主页面
            ColorWarehouseView()
                .tabItem {
                    Label("豆仓", systemImage: "shippingbox")
                }

            // 图纸册 - 图纸列表页
            ProjectListView()
            .tabItem {
                Label("图纸册", systemImage: "book.pages")
            }

            // 设置 - 导入导出、数据管理
            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape")
                }
        }
        .tint(.indigo)
    }
}
