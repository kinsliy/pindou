import SwiftData
import SwiftUI

// ============================================
// ImportSheetView - 离线导入弹窗
// 类似于前端的导入 Modal 或上传组件
// 功能：从剪贴板粘贴 HTML 内容导入颜色数据
// ============================================

struct ImportSheetView: View {
    // ============================================
    // 环境变量
    // ============================================

    @Environment(\.dismiss) private var dismiss  // 关闭弹窗方法
    @Environment(\.modelContext) private var modelContext  // 数据库上下文

    // ============================================
    // Props
    // ============================================

    let existingColors: [BeadColor]  // 当前数据库中已有的颜色
    let onComplete: (ImportResult) -> Void  // 导入完成后的回调

    // ============================================
    // 状态变量
    // ============================================

    @State private var html = ""           // 用户粘贴的 HTML 内容
    @State private var errorMessage: String?  // 错误信息

    // ============================================
    // 服务类
    // ============================================

    private let importService = ColorImportService()  // HTML 解析服务

    // ============================================
    // View 主体
    // ============================================

    var body: some View {
        NavigationStack {
            Form {
                // HTML 内容输入区
                Section("HTML 内容") {
                    TextEditor(text: $html)
                        .frame(minHeight: 260)
                    // TextEditor 相当于 <textarea>
                }

                // 错误提示区
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("离线导入")
            .navigationBarTitleDisplayMode(.inline)

            // 工具栏
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("导入") { importHTML() }
                        .disabled(html.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    // HTML 内容为空时禁用导入按钮
                }
            }
        }
    }

    // ============================================
    // 方法
    // ============================================

    // 执行 HTML 导入
    private func importHTML() {
        do {
            // 1. 解析 HTML 为颜色对象数组
            let imports = try importService.parse(html: html, sourceURL: "manual-html")

            // 2. 批量插入或更新到数据库
            // 类似于前端的 bulkUpsert 或批量 INSERT ON CONFLICT UPDATE
            let result = try importService.upsert(
                imports,
                into: modelContext,
                existingColors: existingColors
            )

            // 3. 执行回调，通知父组件导入结果
            onComplete(result)

            // 4. 关闭弹窗
            dismiss()
        } catch {
            // 解析或保存失败，显示错误信息
            errorMessage = error.localizedDescription
        }
    }
}
