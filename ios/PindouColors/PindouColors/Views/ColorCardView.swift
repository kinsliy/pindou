import SwiftData
import SwiftUI

// ============================================
// ColorCardView - 颜色卡片组件
// 类似于前端 React/Vue 的卡片组件 (Card)
// 功能：展示单个颜色的信息，支持快速增减库存
// ============================================

struct ColorCardView: View {
    // ============================================
    // SwiftData 环境 - 用于数据持久化
    // 类似于前端的 useContext 获取全局状态
    // ============================================
    @Environment(\.modelContext) private var modelContext

    // ============================================
    // Props 属性 - 类似于前端的 props
    // ============================================

    let color: BeadColor              // 颜色数据模型，类似前端的 props.color
    var isCompact = false            // 是否紧凑模式（用于列表视图）
    var onTap: () -> Void            // 点击回调，类似前端的 props.onClick

    // ============================================
    // View 主体 - 相当于前端的 render / return JSX
    // ============================================

    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 10 : 14) {
            // 顶部区域：状态标签 + 菜单
            HStack {

                // 库存状态标签
                Text(color.isStockEnough ? "库存充足" : "需要补豆")
                    .font(.caption.bold())
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .foregroundStyle(color.isStockEnough ? .green : .orange)
                    .overlay(Capsule().stroke(
                        color.isStockEnough ? .green.opacity(0.35) : .orange.opacity(0.45)
                    ))

                Spacer()  // 弹性空间

                // 右上角菜单按钮
                Button(action: onTap) {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(.black.opacity(0.65))  /* 加深，确保在白底上可读 */
                        .frame(width: 36, height: 36)  /* 44pt 最小触摸区域 */
                        .overlay(Circle().stroke(.black.opacity(0.08)))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("编辑\(color.code)")
            }

            // 中间区域：彩色色块上显示色号 + 可编辑库存
            VStack(alignment: .leading, spacing: 6) {
                // 色号 - 在实际颜色上显示，一眼识别
                Text(color.code)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(readableTextColor)

                // 库存编辑
                HStack(spacing: 4) {
                    TextField(
                        "库存",
                        value: Binding(
                            get: { color.stockCount },
                            set: { newValue in
                                color.stockCount = max(0, newValue)
                                color.updatedAt = Date()
                                try? modelContext.save()
                            }
                        ),
                        format: .number
                    )
                    .font(.system(
                        size: isCompact ? 28 : 34,
                        weight: .black
                    ))
                    .foregroundStyle(readableTextColor)
                    .frame(minWidth: 80)  // 确保 4 位数字不截断

                    Text("粒")
                        .font(.headline)
                        .foregroundStyle(readableTextColor.opacity(0.65))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, isCompact ? 10 : 14)
            .background(color.color)  // 用实际颜色作为背景
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.black.opacity(0.1), lineWidth: 2))

        }
        .padding(14)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)  /* iOS 风格阴影 */
    }

    // ============================================
    // 方法 - 类似于前端的 class methods
    // ============================================


    // ============================================
    // 计算属性 - 类似于前端的 computed properties
    // ============================================

    // 根据背景颜色计算文字颜色（黑或白）
    // 目的：确保文字在彩色背景上有足够的对比度
    private var readableTextColor: Color {
        guard let rgb = RGB(hex: color.hex) else {
            return .primary  // 默认黑色
        }
        // 亮度计算公式：0.299*R + 0.587*G + 0.114*B
        // 亮度 > 0.56 用黑色文字，否则用白色文字
        return rgb.luminance > 0.56 ? .black.opacity(0.85) : .white
    }
}

// ============================================
// RGB - 颜色RGB结构体
// 用于计算颜色亮度，类似于前端的颜色工具函数
// ============================================

private struct RGB {
    let red: Double   // 红色分量，范围 0-1
    let green: Double // 绿色分量，范围 0-1
    let blue: Double  // 蓝色分量，范围 0-1

    // 从十六进制字符串解析RGB
    init?(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") {
            value.removeFirst()
        }
        guard value.count == 6, let number = Int(value, radix: 16) else {
            return nil
        }
        // 位运算提取 RGB 分量，类似前端的 parseInt
        red = Double((number >> 16) & 0xFF) / 255
        green = Double((number >> 8) & 0xFF) / 255
        blue = Double(number & 0xFF) / 255
    }

    // 计算亮度 - 用于判断文字颜色
    // 公式：0.299*R + 0.587*G + 0.114*B
    // 这是人眼对绿色最敏感，对蓝色最不敏感的加权公式
    var luminance: Double {
        0.299 * red + 0.587 * green + 0.114 * blue
    }
}
