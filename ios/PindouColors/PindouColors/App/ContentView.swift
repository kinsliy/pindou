import SwiftUI

// ============================================
// ContentView - 应用的主界面组件
// 类似于前端 React/Vue 的根组件 (App.vue / App.jsx)
// ============================================

struct ContentView: View {
    // ============================================
    // View 的主体 - 相当于前端的 render 或 template
    // ============================================

    var body: some View {
        // TabView 类似于前端的 Tab 组件或底部导航
        // 功能类似小程序的自定义 tabBar 或 Web 的分段控制器
        TabView {
            // 第一个 Tab：豆仓（颜色仓库）
            // 相当于前端路由的第一个页面
            ColorWarehouseView()
                .tabItem {
                    // Tab 的显示内容
                    // Label 相当于前端的 <span> + 图标
                    Label("豆仓", systemImage: "shippingbox")
                }

            // 第二个 Tab：图纸册（占位页面）
            // 使用 PlaceholderTabView 快速创建占位页面，类似前端的骨架屏
            PlaceholderTabView(
                title: "图纸册",
                systemImage: "book.pages",
                message: "后续可接图纸和作品配色。"
            )
            .tabItem {
                Label("图纸册", systemImage: "book.pages")
            }

            // 第三个 Tab：灵感库（占位页面）
            PlaceholderTabView(
                title: "灵感库",
                systemImage: "sparkles",
                message: "后续可收藏配色灵感。"
            )
            .tabItem {
                Label("灵感库", systemImage: "sparkles")
            }

            // 第四个 Tab：记录（占位页面）
            PlaceholderTabView(
                title: "记录",
                systemImage: "clock.arrow.circlepath",
                message: "后续可记录入库、出库和同步历史。"
            )
            .tabItem {
                Label("记录", systemImage: "clock.arrow.circlepath")
            }

            // 第五个 Tab：我的（占位页面）
            PlaceholderTabView(
                title: "我的",
                systemImage: "person.crop.circle",
                message: "备份、偏好和数据源设置会放在这里。"
            )
            .tabItem {
                Label("我的", systemImage: "person.crop.circle")
            }
        }
        // .tint() 设置 Tab 选中时的强调色
        // 类似于前端的全局主题色或 ant-design 的 primary color
        .tint(.indigo)
    }
}
