import Foundation
import SwiftData

struct ImportResult: Equatable {
    let parsed: Int
    let inserted: Int
    let updated: Int
    let skipped: Int
}

enum ColorImportError: LocalizedError {
    case emptySource
    case noColorsFound
    case invalidURL

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

struct ColorImportService {
    static let defaultSourceURL = "https://www.pindou.online/colors"

    func fetchDefaultColors() async throws -> [ImportedBeadColor] {
        guard let url = URL(string: Self.defaultSourceURL) else {
            throw ColorImportError.invalidURL
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let html = String(data: data, encoding: .utf8) else {
            throw ColorImportError.emptySource
        }
        return try parse(html: html, sourceURL: Self.defaultSourceURL)
    }

    func parse(html: String, sourceURL: String) throws -> [ImportedBeadColor] {
        let lines = htmlToPlainText(html)
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0 != "点击复制" }

        var items: [ImportedBeadColor] = []
        var currentSeries = ""
        var sortOrder = 0

        for index in lines.indices {
            let line = lines[index]
            if let series = seriesName(at: index, in: lines) {
                currentSeries = series
                continue
            }

            guard !currentSeries.isEmpty, isColorCode(line), index + 1 < lines.count else {
                continue
            }

            let code = line.uppercased()
            let hex = normalizedHex(lines[index + 1])
            guard !hex.isEmpty else {
                continue
            }

            let sourceKeyCandidate = index + 2 < lines.count ? lines[index + 2] : ""
            let sourceKey = sourceKeyCandidate.hasPrefix("Mard_") ? sourceKeyCandidate : "Mard_\(code)"
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

    @MainActor
    func upsert(_ imports: [ImportedBeadColor], into context: ModelContext, existingColors: [BeadColor]) throws -> ImportResult {
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

        for item in imports {
            guard !item.code.isEmpty, !item.series.isEmpty, !item.hex.isEmpty else {
                skipped += 1
                continue
            }

            let sourceKey = item.sourceKey.uppercased()
            let seriesCode = seriesCodeKey(series: item.series, code: item.code)

            if let color = existingBySourceKey[sourceKey] ?? existingBySeriesCode[seriesCode] {
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
                if !color.sourceKey.isEmpty {
                    existingBySourceKey[color.sourceKey.uppercased()] = color
                }
                existingBySeriesCode[seriesCodeKey(series: color.series, code: color.code)] = color
                inserted += 1
            }
        }

        try context.save()
        return ImportResult(parsed: imports.count, inserted: inserted, updated: updated, skipped: skipped)
    }

    private func seriesName(at index: Int, in lines: [String]) -> String? {
        let line = lines[index]
        if line.hasPrefix("##") {
            let series = line.replacingOccurrences(of: "##", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased()
            return series.isEmpty ? nil : series
        }

        guard line.range(of: #"^[A-Z]{1,3}$"#, options: .regularExpression) != nil,
              index + 1 < lines.count,
              lines[index + 1].range(of: #"^\d+\s+Colors$"#, options: [.regularExpression, .caseInsensitive]) != nil
        else {
            return nil
        }
        return line.uppercased()
    }

    private func isColorCode(_ value: String) -> Bool {
        value.range(of: #"^[A-Z]{1,3}\d{1,3}$"#, options: .regularExpression) != nil
    }

    private func normalizedHex(_ value: String) -> String {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard text.range(of: #"^#[0-9A-F]{6}$"#, options: .regularExpression) != nil else {
            return ""
        }
        return text
    }

    private func seriesCodeKey(series: String, code: String) -> String {
        "\(series.uppercased())-\(code.uppercased())"
    }

    private func htmlToPlainText(_ html: String) -> String {
        html
            .replacingOccurrences(of: #"(?is)<script.*?</script>"#, with: "\n", options: .regularExpression)
            .replacingOccurrences(of: #"(?is)<style.*?</style>"#, with: "\n", options: .regularExpression)
            .replacingOccurrences(of: #"(?i)</(div|section|article|li|tr|p|h1|h2|h3|h4|h5|h6)>"#, with: "\n", options: .regularExpression)
            .replacingOccurrences(of: #"(?i)<br\s*/?>"#, with: "\n", options: .regularExpression)
            .replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
    }
}
