import Foundation

struct BackupService {
    struct BackupRecord: Codable {
        let code: String
        let series: String
        let hex: String
        let displayName: String
        let alias: String
        let sortOrder: Int
        let enabled: Bool
        let sourceURL: String
        let sourceKey: String
        let note: String
        let stockCount: Int
    }

    func exportJSON(colors: [BeadColor]) throws -> Data {
        let records = colors.map(record)
        return try JSONEncoder.pretty.encode(records)
    }

    func exportCSV(colors: [BeadColor]) -> Data {
        let header = "code,series,hex,displayName,alias,sortOrder,enabled,sourceURL,sourceKey,stockCount,note"
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
            ].map(csvEscape).joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n").data(using: .utf8) ?? Data()
    }

    func decodeBackup(data: Data) throws -> [ImportedBeadColor] {
        let records = try JSONDecoder().decode([BackupRecord].self, from: data)
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

    private func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
