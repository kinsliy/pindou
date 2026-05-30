import SwiftData
import SwiftUI

// ============================================
// SettingsView - 设置页面
// 包含导入导出、数据管理等操作
// ============================================

struct SettingsView: View {
    // ============================================
    // SwiftData 依赖注入
    // ============================================
    @Environment(\.modelContext) private var modelContext

    // 获取所有颜色用于导入导出
    @Query(sort: [
        SortDescriptor(\BeadColor.series),
        SortDescriptor(\BeadColor.sortOrder),
        SortDescriptor(\BeadColor.code)
    ])
    private var colors: [BeadColor]

    // ============================================
    // 状态变量
    // ============================================

    @State private var isImporting = false       // 导入弹窗
    @State private var isExporting = false       // 导出弹窗
    @State private var alertMessage: String?     // 提示信息
    @State private var exportDocument = ExportDocument()  // 导出文档
    @State private var exportFileName = "pindou-colors.json"  // 导出文件名

    // ============================================
    // 服务类
    // ============================================

    private let backupService = BackupService()

    // ============================================
    // View 主体
    // ============================================

    var body: some View {
        NavigationStack {
            List {
                // 数据管理 - 导入/导出
                Section("数据管理") {
                    // 粘贴 HTML 导入
                    Button {
                        isImporting = true
                    } label: {
                        Label("粘贴 HTML 导入", systemImage: "doc.badge.plus")
                            .foregroundStyle(.primary)
                    }

                    // 导出 JSON
                    Button {
                        exportJSON()
                    } label: {
                        Label("导出 JSON", systemImage: "square.and.arrow.up")
                            .foregroundStyle(.primary)
                    }

                    // 导出 CSV
                    Button {
                        exportCSV()
                    } label: {
                        Label("导出 CSV", systemImage: "tablecells")
                            .foregroundStyle(.primary)
                    }
                }

                // 数据信息
                Section("数据") {
                    HStack {
                        Text("颜色总数")
                        Spacer()
                        Text("\(colors.count)")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("系列数")
                        Spacer()
                        Text("\(seriesCount)")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("总库存")
                        Spacer()
                        Text("\(totalStock.formatted()) 粒")
                            .foregroundStyle(.secondary)
                    }
                }

                // 关于
                Section("关于") {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("数据源")
                        Spacer()
                        Text("Mard 291 色")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.large)

            // 导入弹窗
            .sheet(isPresented: $isImporting) {
                ImportSheetView(existingColors: colors) { result in
                    alertMessage = "导入完成：新增 \(result.inserted)，更新 \(result.updated)"
                }
            }

            // 导出文件选择器
            .fileExporter(
                isPresented: $isExporting,
                document: exportDocument,
                contentType: exportFileName.hasSuffix(".csv") ? .commaSeparatedText : .json,
                defaultFilename: exportFileName
            ) { result in
                if case .failure(let error) = result {
                    alertMessage = error.localizedDescription
                }
            }

            // 提示弹窗
            .alert("提示", isPresented: Binding(
                get: { alertMessage != nil },
                set: { _ in alertMessage = nil }
            )) {
                Button("好", role: .cancel) {}
            } message: {
                Text(alertMessage ?? "")
            }
        }
    }

    // ============================================
    // 计算属性
    // ============================================

    // 系列数
    private var seriesCount: Int {
        Set(colors.map(\.series)).count
    }

    // 总库存
    private var totalStock: Int {
        colors.reduce(0) { $0 + $1.stockCount }
    }

    // ============================================
    // 方法
    // ============================================

    // 导出 JSON
    private func exportJSON() {
        do {
            exportDocument = ExportDocument(data: try backupService.exportJSON(colors: colors))
            exportFileName = "pindou-colors.json"
            isExporting = true
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    // 导出 CSV
    private func exportCSV() {
        exportDocument = ExportDocument(data: backupService.exportCSV(colors: colors))
        exportFileName = "pindou-colors.csv"
        isExporting = true
    }
}
