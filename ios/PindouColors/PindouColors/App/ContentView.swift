import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            ColorWarehouseView()
                .tabItem {
                    Label("豆仓", systemImage: "shippingbox")
                }

            PlaceholderTabView(title: "图纸册", systemImage: "book.pages", message: "后续可接图纸和作品配色。")
                .tabItem {
                    Label("图纸册", systemImage: "book.pages")
                }

            PlaceholderTabView(title: "灵感库", systemImage: "sparkles", message: "后续可收藏配色灵感。")
                .tabItem {
                    Label("灵感库", systemImage: "sparkles")
                }

            PlaceholderTabView(title: "记录", systemImage: "clock.arrow.circlepath", message: "后续可记录入库、出库和同步历史。")
                .tabItem {
                    Label("记录", systemImage: "clock.arrow.circlepath")
                }

            PlaceholderTabView(title: "我的", systemImage: "person.crop.circle", message: "备份、偏好和数据源设置会放在这里。")
                .tabItem {
                    Label("我的", systemImage: "person.crop.circle")
                }
        }
        .tint(.indigo)
    }
}
