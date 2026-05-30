import SwiftData
import SwiftUI

// ============================================
// PindouColorsApp - 应用入口
// 类似于前端的 ReactDOM.render() 或 Vue app.mount()
// 这是 iOS 应用启动时第一个被执行的代码
// ============================================

@main
struct PindouColorsApp: App {
    // ============================================
    // App 主体 - 相当于前端的 App 组件
    // 使用 SwiftUI 的 .modelContainer(for:) 自动创建容器
    // 类似于前端的 <Provider store={store}>
    // ============================================

    var body: some Scene {
        // WindowGroup 窗口组 - 支持多窗口
        // 类似于前端的 BrowserWindow 或小程序 Page
        WindowGroup {
            // ContentView 是根视图组件
            ContentView()
        }
        // modelContainer 自动创建并注入 SwiftData 容器
        // 新模型（Project、ProjectColorUsage）会自动迁移
        .modelContainer(for: [BeadColor.self, Project.self, ProjectColorUsage.self])
    }
}
