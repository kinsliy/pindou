import Foundation
import SwiftData
import SwiftUI

@Model
final class BeadColor {
    @Attribute(.unique) var id: UUID
    var code: String
    var series: String
    var hex: String
    var displayName: String
    var alias: String
    var sortOrder: Int
    var enabled: Bool
    var sourceURL: String
    var sourceKey: String
    var note: String
    var stockCount: Int
    var createdAt: Date
    var updatedAt: Date
    var lastSyncedAt: Date?

    init(
        id: UUID = UUID(),
        code: String,
        series: String,
        hex: String,
        displayName: String = "",
        alias: String = "",
        sortOrder: Int = 0,
        enabled: Bool = true,
        sourceURL: String = "",
        sourceKey: String = "",
        note: String = "",
        stockCount: Int = 1000,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastSyncedAt: Date? = nil
    ) {
        self.id = id
        self.code = code
        self.series = series
        self.hex = hex
        self.displayName = displayName.isEmpty ? code : displayName
        self.alias = alias
        self.sortOrder = sortOrder
        self.enabled = enabled
        self.sourceURL = sourceURL
        self.sourceKey = sourceKey
        self.note = note
        self.stockCount = stockCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastSyncedAt = lastSyncedAt
    }

    var normalizedKey: String {
        if !sourceKey.isEmpty {
            return sourceKey.uppercased()
        }
        return "\(series.uppercased())-\(code.uppercased())"
    }

    var color: Color {
        Color(hex: hex) ?? .gray
    }

    var isStockEnough: Bool {
        stockCount >= 800
    }
}

extension Color {
    init?(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if value.hasPrefix("#") {
            value.removeFirst()
        }
        guard value.count == 6, let number = Int(value, radix: 16) else {
            return nil
        }
        let red = Double((number >> 16) & 0xFF) / 255.0
        let green = Double((number >> 8) & 0xFF) / 255.0
        let blue = Double(number & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue)
    }
}

struct ImportedBeadColor: Identifiable, Codable, Equatable {
    var id: String { normalizedKey }
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

    var normalizedKey: String {
        if !sourceKey.isEmpty {
            return sourceKey.uppercased()
        }
        return "\(series.uppercased())-\(code.uppercased())"
    }
}
