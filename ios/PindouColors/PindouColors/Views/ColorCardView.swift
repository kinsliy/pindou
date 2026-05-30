import SwiftData
import SwiftUI

// ============================================
// ColorCardView - 颜色卡片组件
// 功能：展示单个颜色的信息和库存数量
// 设计：库存数字为文本展示，不可编辑。编辑通过 ellipsis 调用 ColorEditorView
// 原因：1) TextField + .number 在大数字时会被裁剪 / 交互不稳定
//       2) 卡片保持紧凑干净，编辑统一通过弹窗完成
// ============================================

struct ColorCardView: View {
    // ============================================
    // SwiftData 环境
    // ============================================
    @Environment(\.modelContext) private var modelContext

    // ============================================
    // Props 属性
    // ============================================

    let color: BeadColor              // 颜色数据模型
    var isCompact = false            // 是否紧凑模式（用于列表视图）
    var onTap: () -> Void            // 点击回调，打开编辑弹窗

    // ============================================
    // View 主体
    // ============================================

    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 8 : 10) {
            // 顶部区域：库存状态标签 + 菜单按钮
            HStack {
                // 库存状态标签（充足 / 需要补豆）
                Text(color.isStockEnough ? "库存充足" : "需要补豆")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .foregroundStyle(color.isStockEnough ? Color.green : Color.orange)
                    .overlay(Capsule().stroke(
                        color.isStockEnough ? Color.green.opacity(0.35) : Color.orange.opacity(0.45)
                    ))

                Spacer()

                // 右上角菜单按钮，点击打开编辑弹窗
                Button(action: onTap) {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(.black.opacity(0.65))
                        .frame(width: 36, height: 36)
                        .overlay(Circle().stroke(.black.opacity(0.08)))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("编辑\(color.code)")
            }

            // 中间区域：色块上显示色号 + 库存数量
            VStack(alignment: .leading, spacing: 4) {
                // 色号 - 在颜色背景上显示，一眼识别
                Text(color.code)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(readableTextColor)

                // 库存数字 + 单位（文本展示，不可编辑）
                // 修改库存请通过右上角菜单打开编辑弹窗
                HStack(spacing: 4) {
                    Text("\(color.stockCount)")
                        .font(.system(
                            size: isCompact ? 24 : 28,
                            weight: .black,
                            design: .rounded
                        ))
                        .foregroundStyle(readableTextColor)
                        // 动态宽度：让数字能完整显示，不被截断
                        .fixedSize(horizontal: true, vertical: false)
                    Text("粒")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(readableTextColor.opacity(0.65))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, isCompact ? 8 : 12)
            .background(color.color)  // 使用实际颜色作为色块背景
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.black.opacity(0.1), lineWidth: 2))

        }
        .padding(12)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }

    // ============================================
    // 计算属性
    // ============================================

    // 根据色块背景颜色计算文字颜色（黑或白），确保对比度
    private var readableTextColor: Color {
        guard let rgb = RGB(hex: color.hex) else {
            return .primary
        }
        // 亮度 > 0.56 用黑色文字，否则用白色文字
        return rgb.luminance > 0.56 ? .black.opacity(0.85) : .white
    }
}

// ============================================
// RGB - 颜色RGB结构体，用于计算颜色亮度
// ============================================

private struct RGB {
    let red: Double
    let green: Double
    let blue: Double

    init?(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let number = Int(value, radix: 16) else { return nil }
        red = Double((number >> 16) & 0xFF) / 255
        green = Double((number >> 8) & 0xFF) / 255
        blue = Double(number & 0xFF) / 255
    }

    var luminance: Double {
        0.299 * red + 0.587 * green + 0.114 * blue
    }
}
