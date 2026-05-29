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
    // ModelContainer - SwiftData 容器
    // 类似于前端的数据库连接池或 Redux Store
    // 整个应用共享同一个数据容器
    // ============================================

    var sharedModelContainer: ModelContainer = {
        // Schema 定义数据库表结构
        // 类似于前端的数据库 schema 定义或 TypeORM 实体
        let schema = Schema([BeadColor.self])

        // ModelConfiguration 数据库配置
        // isStoredInMemoryOnly: false 表示数据持久化存储
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            // 创建容器，类似前端的 initDatabase()
            return try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
        } catch {
            // 数据库创建失败，应用崩溃
            // 类似于前端的 console.error + process.exit(1)
            fatalError("Could not create SwiftData container: \(error)")
        }
    }()

    // ============================================
    // App 主体 - 相当于前端的 App 组件
    // ============================================

    var body: some Scene {
        // WindowGroup 窗口组 - 支持多窗口
        // 类似于前端的 BrowserWindow 或小程序 Page
        WindowGroup {
            // ContentView 是根视图组件
            ContentView()
        }
        // modelContainer 将数据库注入到视图层级
        // 类似于前端的 <Provider store={store}>
        // 这样所有子视图都可以通过 @Environment(\.modelContext) 访问数据库
        .modelContainer(sharedModelContainer)
    }
}
