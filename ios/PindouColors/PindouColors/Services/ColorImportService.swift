import Foundation
import SwiftData

// ============================================
// ImportResult - 导入结果数据结构
// 类似于前端的 API 响应类型定义
// ============================================

struct ImportResult: Equatable {
    let parsed: Int    // 解析的总数量
    let inserted: Int  // 新增数量
    let updated: Int   // 更新数量
    let skipped: Int   // 跳过数量
}

// ============================================
// ColorImportError - 导入错误枚举
// 类似于前端的自定义 Error 类
// ============================================

enum ColorImportError: LocalizedError {
    case emptySource      // 空数据源
    case noColorsFound    // 未找到颜色
    case invalidURL       // URL 无效

    var errorDescription: String? {
        switch self {
        case .emptySource:
            return "没有可导入的内容"
        case .noColorsFound:
            return "没有解析到颜色"
        case .invalidURL:
            return "数据源链接无效"
        }
    }
}

// ============================================
// ColorImportService - 颜色导入服务
// 类似于前端的 API 服务层（如 axios 实例）
// 功能：从网络或 HTML 解析导入颜色数据
// ============================================

struct ColorImportService {
    // 默认数据源 URL
    static let defaultSourceURL = "https://www.pindou.online/colors"

    // ============================================
    // 从默认 URL 获取颜色数据
    // 类似于前端的 api.getColors()
    // ============================================

    func fetchDefaultColors() async throws -> [ImportedBeadColor] {
        guard let url = URL(string: Self.defaultSourceURL) else {
            throw ColorImportError.invalidURL
        }

        // URLSession.shared.data() 类似于前端的 fetch()
        let (data, _) = try await URLSession.shared.data(from: url)

        guard let html = String(data: data, encoding: .utf8) else {
            throw ColorImportError.emptySource
        }

        // 解析 HTML
        return try parse(html: html, sourceURL: Self.defaultSourceURL)
    }

    // ============================================
    // 解析 HTML 文本为颜色对象数组
    // 类似于前端的 parseHTML() 或cheerio 解析库
    // ============================================

    func parse(html: String, sourceURL: String) throws -> [ImportedBeadColor] {
        // 1. HTML 转纯文本
        let lines = htmlToPlainText(html)
            .components(separatedBy: .newlines)  // 按行分割
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }  // 去除首尾空白
            .filter { !$0.isEmpty && $0 != "点击复制" }  // 过滤空行和"点击复制"

        var items: [ImportedBeadColor] = []
        var currentSeries = ""   // 当前系列
        var sortOrder = 0        // 排序序号

        // 2. 逐行解析
        for index in lines.indices {
            let line = lines[index]

            // 检测是否是系列标题行
            if let series = seriesName(at: index, in: lines) {
                currentSeries = series
                continue
            }

            // 验证是否是有效的色号格式（如 A1, B22）
            guard !currentSeries.isEmpty,
                  isColorCode(line),
                  index + 1 < lines.count else {
                continue
            }

            let code = line.uppercased()           // 色号转大写
            let hex = normalizedHex(lines[index + 1])  // 下一行是 HEX 值
            guard !hex.isEmpty else {
                continue
            }

            // 尝试获取源 Key（通常在第三行）
            let sourceKeyCandidate = index + 2 < lines.count ? lines[index + 2] : ""
            let sourceKey = sourceKeyCandidate.hasPrefix("Mard_") ?
                sourceKeyCandidate : "Mard_\(code)"

            sortOrder += 1
            items.append(
                ImportedBeadColor(
                    code: code,
                    series: currentSeries,
                    hex: hex,
                    displayName: code,
                    alias: "",
                    sortOrder: sortOrder,
                    enabled: true,
                    sourceURL: sourceURL,
                    sourceKey: sourceKey,
                    note: "",
                    stockCount: 1000
                )
            )
        }

        guard !items.isEmpty else {
            throw ColorImportError.noColorsFound
        }
        return items
    }

    // ============================================
    // 批量插入或更新颜色到数据库
    // 类似于前端的 bulkUpsert 或批量 INSERT ON CONFLICT UPDATE
    // ============================================

    @MainActor
    func upsert(
        _ imports: [ImportedBeadColor],
        into context: ModelContext,
        existingColors: [BeadColor]
    ) throws -> ImportResult {
        // 1. 构建已有数据的索引Map，类似前端的 Map 或 Record
        var existingBySourceKey: [String: BeadColor] = [:]
        var existingBySeriesCode: [String: BeadColor] = [:]

        for color in existingColors {
            if !color.sourceKey.isEmpty {
                existingBySourceKey[color.sourceKey.uppercased()] = color
            }
            existingBySeriesCode[seriesCodeKey(series: color.series, code: color.code)] = color
        }

        var inserted = 0
        var updated = 0
        var skipped = 0
        let now = Date()

        // 2. 遍历导入数据，插入或更新
        for item in imports {
            guard !item.code.isEmpty, !item.series.isEmpty, !item.hex.isEmpty else {
                skipped += 1
                continue
            }

            let sourceKey = item.sourceKey.uppercased()
            let seriesCode = seriesCodeKey(series: item.series, code: item.code)

            // 查找是否已存在
            if let color = existingBySourceKey[sourceKey] ?? existingBySeriesCode[seriesCode] {
                // 已存在：更新
                color.hex = item.hex
                color.displayName = item.displayName
                color.sortOrder = item.sortOrder
                color.enabled = item.enabled
                color.sourceURL = item.sourceURL
                color.sourceKey = item.sourceKey
                color.updatedAt = now
                color.lastSyncedAt = now
                updated += 1
            } else {
                // 不存在：新建
                let color = BeadColor(
                    code: item.code,
                    series: item.series,
                    hex: item.hex,
                    displayName: item.displayName,
                    alias: item.alias,
                    sortOrder: item.sortOrder,
                    enabled: item.enabled,
                    sourceURL: item.sourceURL,
                    sourceKey: item.sourceKey,
                    note: item.note,
                    stockCount: item.stockCount,
                    createdAt: now,
                    updatedAt: now,
                    lastSyncedAt: now
                )
                context.insert(color)

                // 更新索引
                if !color.sourceKey.isEmpty {
                    existingBySourceKey[color.sourceKey.uppercased()] = color
                }
                existingBySeriesCode[seriesCodeKey(series: color.series, code: color.code)] = color
                inserted += 1
            }
        }

        // 3. 保存到数据库
        try context.save()

        return ImportResult(
            parsed: imports.count,
            inserted: inserted,
            updated: updated,
            skipped: skipped
        )
    }

    // ============================================
    // 私有辅助方法
    // ============================================

    // 检测是否是系列名称行
    private func seriesName(at index: Int, in lines: [String]) -> String? {
        let line = lines[index]

        // 格式 1: ## A 系列
        if line.hasPrefix("##") {
            let series = line.replacingOccurrences(of: "##", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased()
            return series.isEmpty ? nil : series
        }

        // 格式 2: A (下一行是 "X Colors")
        guard line.range(of: #"^[A-Z]{1,3}$"#, options: .regularExpression) != nil,
              index + 1 < lines.count,
              lines[index + 1].range(of: #"^\d+\s+Colors$"#, options: [.regularExpression, .caseInsensitive]) != nil
        else {
            return nil
        }
        return line.uppercased()
    }

    // 检测是否是色号（如 A1, B22, ABC123）
    private func isColorCode(_ value: String) -> Bool {
        value.range(of: #"^[A-Z]{1,3}\d{1,3}$"#, options: .regularExpression) != nil
    }

    // 标准化 HEX 值
    private func normalizedHex(_ value: String) -> String {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard text.range(of: #"^#[0-9A-F]{6}$"#, options: .regularExpression) != nil else {
            return ""
        }
        return text
    }

    // 生成系列-色号组合键
    private func seriesCodeKey(series: String, code: String) -> String {
        "\(series.uppercased())-\(code.uppercased())"
    }

    // HTML 转纯文本
    // 类似于前端的 DOMParser 或 HTML 正则替换
    private func htmlToPlainText(_ html: String) -> String {
        html
            // 移除 script 和 style 标签内容
            .replacingOccurrences(of: #"(?is)<script.*?</script>"#, with: "\n", options: .regularExpression)
            .replacingOccurrences(of: #"(?is)<style.*?</style>"#, with: "\n", options: .regularExpression)
            // 块级标签替换为换行
            .replacingOccurrences(of: #"(?i)</(div|section|article|li|tr|p|h1|h2|h3|h4|h5|h6)>"#, with: "\n", options: .regularExpression)
            .replacingOccurrences(of: #"(?i)<br\s*/?>"#, with: "\n", options: .regularExpression)
            // 移除所有标签
            .replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
            // HTML 实体转义
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
    }
}
