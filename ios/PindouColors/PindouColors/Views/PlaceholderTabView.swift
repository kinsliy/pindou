import SwiftUI

// ============================================
// PlaceholderTabView - 占位页面组件
// 类似于前端的骨架屏或开发中的占位组件
// 功能：显示尚未实现的页面，给用户友好的提示
// ============================================

struct PlaceholderTabView: View {
    // ============================================
    // Props - 类似于前端的 props
    // ============================================

    let title: String       // 页面标题
    let systemImage: String // SF Symbols 图标名称
    let message: String     // 提示信息

    // ============================================
    // View 主体
    // ============================================

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                // 图标
                Image(systemName: systemImage)
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(.indigo)

                // 标题
                Text(title)
                    .font(.title.bold())

                // 提示信息
                Text(message)
                    .font(.body)
                    .foregroundStyle(.black.opacity(0.65))  /* 加深，确保在白底上可读 */
                    .multilineTextAlignment(.center)  // 居中对齐
                    .padding(.horizontal)
            }
            // 占据整个可用空间
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 0.97, green: 0.98, blue: 1.0))
        }
    }
}
