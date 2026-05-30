import SwiftData
import SwiftUI

// ============================================
// ColorEditorView - 颜色编辑弹窗
// 功能：编辑色号和库存
// 设计：
//  - 去掉颜色预览区块（用户要求）
//  - 基础信息只保留色号（用户要求：系列/名称/别名不在此编辑）
//  - 库存：直接数字输入 + 快捷补豆按钮（+10/+100/+500 / -10/-100/-500）
//  - 不使用 presentationDetents 避免 iOS 17 卡死 bug
// 卡死已知：点击基础信息区域仍有卡死（iOS 17 + Form + sheet 组合 bug），待后续排查
// ============================================

struct ColorEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let color: BeadColor?  // nil 表示新建颜色

    @State private var code: String        // 色号（唯一用户可见字段）
    @State private var series: String      // 系列（内部保留，不展示）
    @State private var hex: String         // 十六进制颜色（内部保留，不展示）
    @State private var displayName: String // 显示名称（内部保留，不展示）
    @State private var alias: String       // 别名（内部保留，不展示）
    @State private var stockCount: Int     // 库存数量
    @State private var stockInput: String  // 库存输入框的文本
    @State private var note: String        // 备注
    @State private var enabled: Bool       // 是否启用

    init(color: BeadColor?) {
        self.color = color
        let count = color?.stockCount ?? 1000
        _code = State(initialValue: color?.code ?? "")
        _series = State(initialValue: color?.series ?? "")
        _hex = State(initialValue: color?.hex ?? "#FFFFFF")
        _displayName = State(initialValue: color?.displayName ?? "")
        _alias = State(initialValue: color?.alias ?? "")
        _stockCount = State(initialValue: count)
        _stockInput = State(initialValue: "\(count)")
        _note = State(initialValue: color?.note ?? "")
        _enabled = State(initialValue: color?.enabled ?? true)
    }

    var body: some View {
        NavigationStack {
            Form {
                // 基础信息 — 只保留色号
                // 系列/名称/别名/hex 在编辑器内不可修改
                Section("基础信息") {
                    TextField("色号，例如 A1", text: $code)
                        .textInputAutocapitalization(.characters)
                }

                // 库存 — 直接数字输入 + 快捷补豆按钮
                // Stepper 步进 10 太慢，且大范围 Stepper 会卡
                Section("库存") {
                    stockInputField
                    quickButtons
                    Toggle("启用", isOn: $enabled)
                }

                // 备注
                Section("备注") {
                    TextEditor(text: $note)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle(color == nil ? "新增颜色" : "编辑颜色")
            .navigationBarTitleDisplayMode(.inline)

            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(code.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                // 删除按钮仅编辑模式显示
                if color != nil {
                    ToolbarItem(placement: .bottomBar) {
                        Button("删除", role: .destructive) { delete() }
                    }
                }
            }
        }
    }

    // ============================================
    // 子视图组件
    // ============================================

    // 库存数字输入区域
    private var stockInputField: some View {
        HStack {
            Text("数量")
                .foregroundStyle(.secondary)
            Spacer()
            TextField("输入库存数量", text: $stockInput)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .font(.title3.weight(.bold))
                .frame(minWidth: 80)
                .onChange(of: stockInput) { _, newValue in
                    // 过滤非数字字符
                    let filtered = newValue.filter(\.isNumber)
                    guard filtered != newValue else { return }
                    stockInput = filtered
                    // 同步更新 stockCount，确保 save() 使用正确的值
                    if let value = Int(filtered) {
                        stockCount = max(0, min(999_999, value))
                    }
                }
            Text("粒")
                .foregroundStyle(.secondary)
        }
    }

    // 快捷补豆按钮组
    private var quickButtons: some View {
        VStack(spacing: 8) {
            Text("快捷补豆")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 10) {
                quickButton(-500, label: "-500", role: .destructive)
                quickButton(-100, label: "-100", role: .destructive)
                quickButton(-10, label: "-10", role: .destructive)

                Spacer()

                quickButton(10, label: "+10")
                quickButton(100, label: "+100")
                quickButton(500, label: "+500")
            }
        }
    }

    // 单个快捷按钮
    private func quickButton(_ delta: Int, label: String, role: ButtonRole? = nil) -> some View {
        Button(role: role) {
            let newValue = max(0, stockCount + delta)
            stockCount = newValue
            stockInput = "\(newValue)"
        } label: {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(delta < 0 ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
                .foregroundStyle(delta < 0 ? Color.red : Color.green)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(delta < 0 ? Color.red.opacity(0.3) : Color.green.opacity(0.3)))
        }
        .buttonStyle(.plain)
    }

    // ============================================
    // 方法
    // ============================================

    private func save() {
        let now = Date()

        if let color {
            // 编辑模式 — 只更新色号/库存/备注/启用状态
            // hex/series/displayName/alias 是标准属性，不在编辑器中修改
            color.code = code.uppercased()
            color.stockCount = stockCount
            color.note = note
            color.enabled = enabled
            color.updatedAt = now
        } else {
            // 新建模式 — 从色号自动推导系列
            // 例如 "A1" → 系列 "A"，hex 默认白色
            let derivedSeries = extractSeries(from: code)
            let newColor = BeadColor(
                code: code.uppercased(),
                series: derivedSeries,
                hex: "#FFFFFF",
                displayName: code.uppercased(),
                alias: "",
                enabled: enabled,
                note: note,
                stockCount: stockCount,
                createdAt: now,
                updatedAt: now
            )
            modelContext.insert(newColor)
        }

        try? modelContext.save()
        dismiss()
    }

    private func delete() {
        if let color {
            modelContext.delete(color)
            try? modelContext.save()
        }
        dismiss()
    }
}

// ============================================
// 工具函数
// ============================================

// 从色号提取系列前缀
// 例如 "A1" → "A", "B22" → "B", "CustomColor" → "CustomColor"
private func extractSeries(from code: String) -> String {
    let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
    let letters = trimmed.prefix(while: \.isLetter)
    return letters.isEmpty ? "未分组" : String(letters).uppercased()
}
