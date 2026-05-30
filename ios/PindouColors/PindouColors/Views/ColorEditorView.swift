import SwiftData
import SwiftUI

// ============================================
// ColorEditorView - 颜色编辑弹窗
// 类似于前端 React/Vue 的 Modal/Dialog 组件
// 功能：新建或编辑颜色信息
// ============================================

struct ColorEditorView: View {
    // ============================================
    // 环境变量 - 类似于前端的 useContext / useLocation
    // ============================================

    @Environment(\.dismiss) private var dismiss
    // dismiss 是 SwiftUI 提供的关闭弹窗方法，类似前端的 onClose

    @Environment(\.modelContext) private var modelContext
    // modelContext 用于数据操作，类似前端的数据库连接

    // ============================================
    // Props - 类似于前端的 props
    // ============================================

    let color: BeadColor?  // 要编辑的颜色，nil 表示新建

    // ============================================
    // 状态变量 - 类似于前端的 useState
    // 使用 @State 包装，值变化时触发 UI 更新
    // ============================================

    @State private var code: String        // 色号
    @State private var series: String      // 系列
    @State private var hex: String         // 十六进制颜色
    @State private var displayName: String // 显示名称
    @State private var alias: String       // 别名
    @State private var stockCount: Int    // 库存数量
    @State private var note: String        // 备注
    @State private var enabled: Bool       // 是否启用

    // ============================================
    // 初始化方法 - 类似于前端的 useEffect / componentDidMount
    // ============================================

    init(color: BeadColor?) {
        self.color = color
        // 初始化表单值，如果有 color 则是编辑模式，否则是新建模式
        _code = State(initialValue: color?.code ?? "")
        _series = State(initialValue: color?.series ?? "")
        _hex = State(initialValue: color?.hex ?? "#FFFFFF")
        _displayName = State(initialValue: color?.displayName ?? "")
        _alias = State(initialValue: color?.alias ?? "")
        _stockCount = State(initialValue: color?.stockCount ?? 1000)
        _note = State(initialValue: color?.note ?? "")
        _enabled = State(initialValue: color?.enabled ?? true)
    }

    // ============================================
    // View 主体 - 相当于前端的 render / return JSX
    // ============================================

    var body: some View {
        NavigationStack {
            Form {
                // 颜色预览区域
                Section {
                    // 实时颜色预览 - 自动选择黑/白文字
                    ZStack(alignment: .bottomLeading) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: hex) ?? .gray)
                            .frame(height: 96)

                        // 左下角显示 HEX 值，自动适配颜色亮度
                        Text(hex.uppercased())
                            .font(.title2.bold())
                            .padding()
                            .foregroundStyle(readableTextColor)
                    }
                }

                // 基础信息表单
                Section("基础信息") {
                    // TextField 类似于前端的 <input> 或 <Form.Input>
                    TextField("色号，例如 A1", text: $code)
                        .textInputAutocapitalization(.characters)  // 自动转大写

                    TextField("系列，例如 A", text: $series)
                        .textInputAutocapitalization(.characters)

                    TextField("HEX，例如 #FAF4C8", text: $hex)
                        .textInputAutocapitalization(.characters)

                    TextField("名称", text: $displayName)

                    TextField("别名", text: $alias)
                }

                // 库存表单
                Section("库存") {
                    // Stepper 类似于前端的数字输入框 + 加减按钮
                    Stepper(value: $stockCount, in: 0...999_999, step: 10) {
                        Text("\(stockCount.formatted()) 粒")
                    }
                    // 范围 0-999999，每次增减 10

                    Toggle("启用", isOn: $enabled)
                    // Toggle 类似于前端的 Switch 开关组件
                }

                // 备注表单
                Section("备注") {
                    TextEditor(text: $note)
                        .frame(minHeight: 120)
                    // TextEditor 类似于前端的 <textarea> 多行文本框
                }
            }
            // NavigationStack 的标题栏配置
            .navigationTitle(color == nil ? "新增颜色" : "编辑颜色")
            .navigationBarTitleDisplayMode(.inline)

            // 工具栏按钮
            .toolbar {
                // 取消按钮
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                    // placement: .cancellationAction 通常在左边
                }

                // 保存按钮
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        // disabled: 禁用条件，类似前端的 disabled={!isValid}
                        .disabled(
                            code.trimmingCharacters(in: .whitespaces).isEmpty ||
                            series.trimmingCharacters(in: .whitespaces).isEmpty
                        )
                    // 色号和系列不能为空
                }

                // 删除按钮（仅编辑模式显示）
                if color != nil {
                    ToolbarItem(placement: .bottomBar) {
                        Button("删除", role: .destructive) { delete() }
                        // role: .destructive 显示为红色警告样式
                    }
                }
            }
        }
    }

    // ============================================
    // 方法 - 类似于前端的 class methods 或工具函数
    // ============================================

    // 保存数据
    private func save() {
        let now = Date()  // 获取当前时间

        if let color {
            // 编辑模式：更新现有数据
            // 类似于前端的 Object.assign 或 spread 操作
            color.code = code.uppercased()
            color.series = series.uppercased()
            color.hex = hex.uppercased()
            color.displayName = displayName.isEmpty ? code.uppercased() : displayName
            color.alias = alias
            color.stockCount = stockCount
            color.note = note
            color.enabled = enabled
            color.updatedAt = now
        } else {
            // 新建模式：创建新数据
            let newColor = BeadColor(
                code: code.uppercased(),
                series: series.uppercased(),
                hex: hex.uppercased(),
                displayName: displayName.isEmpty ? code.uppercased() : displayName,
                alias: alias,
                enabled: enabled,
                note: note,
                stockCount: stockCount,
                createdAt: now,
                updatedAt: now
            )
            // 插入到数据库，类似前端的 db.create() 或 INSERT
            modelContext.insert(newColor)
        }

        // 保存所有更改，类似前端的 db.save() 或 commit
        try? modelContext.save()

        // 关闭弹窗，类似前端的 onClose()
        dismiss()
    }

    // 删除数据
    // 计算颜色亮度，决定文字用黑色还是白色
    private var readableTextColor: Color {
        guard let rgb = RGB(hex: hex) else { return .primary }
        return rgb.luminance > 0.56 ? .black.opacity(0.85) : .white
    }

    private func delete() {
        if let color {
            // 从数据库删除，类似前端的 db.delete() 或 DELETE FROM
            modelContext.delete(color)
            try? modelContext.save()
        }
        dismiss()
    }
}


// ============================================
// RGB - 颜色RGB结构体（用于计算颜色亮度）
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
