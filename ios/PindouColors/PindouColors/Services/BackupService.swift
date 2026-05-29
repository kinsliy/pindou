import Foundation

// ============================================
// BackupService - 备份服务
// 类似于前端的导出/导入工具函数
// 功能：导出颜色数据为 JSON/CSV，导入备份文件
// ============================================

struct BackupService {
    // ============================================
    // 内部数据结构 - 备份记录
    // 类似于前端的 TypeScript 接口定义
    // ============================================

    struct BackupRecord: Codable {
        let code: String         // 色号
        let series: String       // 系列
        let hex: String          // 十六进制颜色
        let displayName: String   // 显示名称
        let alias: String        // 别名
        let sortOrder: Int       // 排序顺序
        let enabled: Bool        // 是否启用
        let sourceURL: String    // 来源 URL
        let sourceKey: String    // 来源 Key
        let note: String         // 备注
        let stockCount: Int      // 库存数量
    }

    // ============================================
    // 导出为 JSON
    // 类似于前端的 JSON.stringify() 或文件下载
    // ============================================

    func exportJSON(colors: [BeadColor]) throws -> Data {
        // 将颜色转换为备份记录
        let records = colors.map(record)

        // JSONEncoder 类似于 JSON.stringify
        // pretty 是自定义的扩展属性，输出格式化 JSON
        return try JSONEncoder.pretty.encode(records)
    }

    // ============================================
    // 导出为 CSV
    // 类似于前端的 csv-stringify 或 Excel 导出
    // ============================================

    func exportCSV(colors: [BeadColor]) -> Data {
        // CSV 表头
        let header = "code,series,hex,displayName,alias,sortOrder,enabled,sourceURL,sourceKey,stockCount,note"

        // 将每条颜色转换为 CSV 行
        let rows = colors.map { color in
            [
                color.code,
                color.series,
                color.hex,
                color.displayName,
                color.alias,
                String(color.sortOrder),
                String(color.enabled),
                color.sourceURL,
                color.sourceKey,
                String(color.stockCount),
                color.note
            ]
            .map(csvEscape)  // 对每个字段进行 CSV 转义
            .joined(separator: ",")
        }

        // 合并为最终 CSV 文本
        return ([header] + rows).joined(separator: "\n").data(using: .utf8) ?? Data()
    }

    // ============================================
    // 从 JSON 备份恢复数据
    // 类似于前端的 JSON.parse() 或文件上传
    // ============================================

    func decodeBackup(data: Data) throws -> [ImportedBeadColor] {
        // JSONDecoder 类似于 JSON.parse
        let records = try JSONDecoder().decode([BackupRecord].self, from: data)

        // 转换为 ImportedBeadColor 数组
        return records.map {
            ImportedBeadColor(
                code: $0.code,
                series: $0.series,
                hex: $0.hex,
                displayName: $0.displayName,
                alias: $0.alias,
                sortOrder: $0.sortOrder,
                enabled: $0.enabled,
                sourceURL: $0.sourceURL,
                sourceKey: $0.sourceKey,
                note: $0.note,
                stockCount: $0.stockCount
            )
        }
    }

    // ============================================
    // 私有辅助方法
    // ============================================

    // 将 BeadColor 转换为 BackupRecord
    private func record(from color: BeadColor) -> BackupRecord {
        BackupRecord(
            code: color.code,
            series: color.series,
            hex: color.hex,
            displayName: color.displayName,
            alias: color.alias,
            sortOrder: color.sortOrder,
            enabled: color.enabled,
            sourceURL: color.sourceURL,
            sourceKey: color.sourceKey,
            note: color.note,
            stockCount: color.stockCount
        )
    }

    // CSV 字段转义
    // 如果字段包含逗号、引号或换行，需要用引号包裹并转义内部引号
    private func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            // 用双引号包裹，并将内部双引号替换为两个双引号
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}

// ============================================
// JSONEncoder 扩展 - 格式化输出
// 类似于前端的 JSON.stringify(obj, null, 2)
// ============================================

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
