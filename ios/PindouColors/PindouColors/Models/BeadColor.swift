import Foundation
import SwiftData
import SwiftUI

@Model
final class BeadColor {
    // ============================================
    // 属性定义 - 类似前端的数据模型/TypeScript 接口
    // ============================================

    // 唯一标识符 - 相当于数据库主键，类似前端的 uuid
    @Attribute(.unique) var id: UUID

    // 色号代码 - 例如 "A1", "B2" 等，相当于颜色的唯一编码
    var code: String

    // 系列名称 - 例如 "A", "B" 系列，用于分组管理颜色
    var series: String

    // 十六进制颜色值 - 例如 "#FF5733"，用于显示实际颜色
    var hex: String

    // 显示名称 - 用于 UI 展示的名称，可自定义
    var displayName: String

    // 别名 - 颜色的其他名称或昵称
    var alias: String

    // 排序顺序 - 数字越小越靠前，用于控制列表中的显示顺序
    var sortOrder: Int

    // 是否启用 - false 时该颜色不显示在列表中，类似前端的 enabled 开关
    var enabled: Bool

    // 来源 URL - 记录颜色数据的来源网站
    var sourceURL: String

    // 来源 Key - 用于去重的唯一键
    var sourceKey: String

    // 备注 - 用户可以添加的额外说明
    var note: String

    // 库存数量 - 当前该颜色的库存粒数，初始为 1000
    var stockCount: Int

    // 创建时间 - 类似前端的 createdAt 时间戳
    var createdAt: Date

    // 更新时间 - 类似前端的 updatedAt 时间戳
    var updatedAt: Date

    // 最后同步时间 - 记录从服务器同步的时间
    var lastSyncedAt: Date?

    // ============================================
    // 初始化方法 - 类似前端的构造函数
    // ============================================

    init(
        id: UUID = UUID(),              // 默认生成新的 UUID
        code: String,                   // 必填：色号代码
        series: String,                  // 必填：系列名称
        hex: String,                     // 必填：十六进制颜色
        displayName: String = "",       // 可选：显示名称，默认用 code
        alias: String = "",              // 可选：别名
        sortOrder: Int = 0,             // 可选：排序顺序，默认 0
        enabled: Bool = true,            // 可选：是否启用，默认 true
        sourceURL: String = "",         // 可选：来源 URL
        sourceKey: String = "",          // 可选：来源 Key
        note: String = "",              // 可选：备注
        stockCount: Int = 1000,          // 可选：库存数量，默认 1000
        createdAt: Date = Date(),       // 可选：创建时间，默认当前时间
        updatedAt: Date = Date(),       // 可选：更新时间，默认当前时间
        lastSyncedAt: Date? = nil       // 可选：最后同步时间
    ) {
        self.id = id
        self.code = code
        self.series = series
        self.hex = hex
        // 如果 displayName 为空，就用 code 作为显示名称
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

    // ============================================
    // 计算属性 - 类似前端的 getter 或 computed 属性
    // ============================================

    // 规范化 Key - 用于去重和匹配
    // 类似于前端的数据规范化处理
    var normalizedKey: String {
        if !sourceKey.isEmpty {
            // 如果有 sourceKey，就用它（转大写）
            return sourceKey.uppercased()
        }
        // 否则用 "系列-色号" 的格式
        return "\(series.uppercased())-\(code.uppercased())"
    }

    // 转换为 SwiftUI 的 Color 对象
    // 类似于前端把 hex 字符串转换为 color 对象
    var color: Color {
        Color(hex: hex) ?? .gray
    }

    // 判断库存是否充足（>= 800 粒为充足）
    // 类似于前端的 computed 属性或格式化方法
    var isStockEnough: Bool {
        stockCount >= 800
    }
}

// ============================================
// Color 扩展 - 为 SwiftUI 的 Color 添加功能
// 类似于前端的 prototype 扩展或工具函数
// ============================================

extension Color {
    // 从十六进制字符串创建 Color
    // 参数: hex 格式为 "#RRGGBB" 或 "RRGGBB"
    // 返回: Color 对象，如果格式错误则返回 nil
    init?(hex: String) {
        // 1. 去除首尾空白和大写转换，类似前端的 trim().toUpperCase()
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        // 2. 去掉开头的 # 号
        if value.hasPrefix("#") {
            value.removeFirst()
        }

        // 3. 验证格式：必须是 6 位十六进制数
        // 类似于前端的正则验证
        guard value.count == 6, let number = Int(value, radix: 16) else {
            return nil
        }

        // 4. 解析十六进制颜色值
        // Swift 的位运算，与前端的 parseInt 类似
        let red = Double((number >> 16) & 0xFF) / 255.0    // 提取红色分量 (RR)
        let green = Double((number >> 8) & 0xFF) / 255.0  // 提取绿色分量 (GG)
        let blue = Double(number & 0xFF) / 255.0          // 提取蓝色分量 (BB)

        // 5. 调用 Color 的初始化方法创建颜色对象
        self.init(red: red, green: green, blue: blue)
    }
}

// ============================================
// 导入数据结构 - 用于解析外部导入的颜色数据
// 类似于前端的 DTO (Data Transfer Object) 或接口定义
// ============================================

struct ImportedBeadColor: Identifiable, Codable, Equatable {
    // 唯一标识 - 使用 normalizedKey 作为 id，类似前端的 id 字段
    var id: String { normalizedKey }

    // 以下字段与 BeadColor 类似
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

    // 规范化 Key - 与 BeadColor 的计算属性相同逻辑
    var normalizedKey: String {
        if !sourceKey.isEmpty {
            return sourceKey.uppercased()
        }
        return "\(series.uppercased())-\(code.uppercased())"
    }
}
