import Foundation
import SwiftData

// ============================================
// DefaultColorCatalog - 默认颜色目录
// 类似于前端的静态数据文件（如 colors.json）
// 包含了应用内置的 291 种默认拼豆颜色
// ============================================

struct DefaultColorCatalog {
    // 来源标识
    static let sourceURL = "bundled-mard-291"

    // 所有默认颜色的数组
    // 类似于前端的 const defaultColors = [...]
    static let colors: [ImportedBeadColor] = rawColors.enumerated().map { index, item in
        ImportedBeadColor(
            code: item.code,              // 色号，如 "A1"
            series: item.series,          // 系列，如 "A"
            hex: item.hex,                // HEX 值，如 "#FAF4C8"
            displayName: item.code,       // 显示名称
            alias: "",                    // 别名（默认空）
            sortOrder: index + 1,         // 排序从 1 开始
            enabled: true,                // 默认启用
            sourceURL: sourceURL,         // 来源
            sourceKey: "Mard_\(item.code)",  // 唯一键
            note: "",                     // 备注
            stockCount: 1000              // 默认库存 1000 粒
        )
    }

    // ============================================
    // 原始颜色数据
    // 这是一个元组数组，包含 (code, series, hex) 三元组
    // 类似于前端的 rawColors 数据文件
    // ============================================

    private static let rawColors: [(code: String, series: String, hex: String)] = [
        // A 系列 - 黄色系
        ("A1", "A", "#FAF4C8"),
        ("A2", "A", "#FFFFD5"),
        ("A3", "A", "#FEFF8B"),
        // ... 更多颜色
    ]
}

// ============================================
// DefaultColorSeedService - 默认颜色种子服务
// 类似于前端的数据库初始化脚本 (seed script)
// 功能：将默认颜色批量插入数据库
// ============================================

struct DefaultColorSeedService {
    // ============================================
    // 插入缺失的默认颜色
    // 类似于前端的 seed 或 init script
    // 只插入数据库中不存在的颜色
    // ============================================

    @MainActor
    func insertMissingDefaults(
        into context: ModelContext,
        existingColors: [BeadColor]
    ) throws -> ImportResult {
        // 1. 创建已有颜色的 Key 集合，用于快速查找
        let existingKeys = Set(existingColors.map(\.normalizedKey))
        let now = Date()
        var inserted = 0

        // 2. 遍历默认颜色目录
        for item in DefaultColorCatalog.colors {
            // 如果已存在，跳过
            if existingKeys.contains(item.normalizedKey) {
                continue
            }

            // 3. 创建新的 BeadColor 并插入数据库
            context.insert(
                BeadColor(
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
            )
            inserted += 1
        }

        // 4. 保存到数据库
        try context.save()

        // 5. 返回统计结果
        return ImportResult(
            parsed: DefaultColorCatalog.colors.count,
            inserted: inserted,
            updated: 0,
            skipped: DefaultColorCatalog.colors.count - inserted
        )
    }
}
