import Foundation
import SwiftData
import SwiftUI

// ============================================
// ProjectStatus - 图纸状态枚举
// ============================================

enum ProjectStatus: String, Codable, CaseIterable, Identifiable {
    case notStarted = "未开始"      // 还未开始拼
    case inProgress = "拼图中"      // 正在拼的过程中
    case completed = "已完成"       // 拼完了

    var id: String { rawValue }
}

// ============================================
// Project - 图纸数据模型
// 每张图纸包含图片、名称、状态、所用颜色列表等
// ============================================

@Model
final class Project {
    // ============================================
    // 基础属性
    // ============================================

    // 唯一标识符
    @Attribute(.unique) var id: UUID

    // 图纸名称（用户可自定义）
    var name: String

    // 图纸状态：未开始/拼图中/已完成
    var status: ProjectStatus.RawValue

    // 创建时间
    var createdAt: Date

    // 更新时间
    var updatedAt: Date

    // 备注（用户可添加额外说明）
    var note: String

    // ============================================
    // 图片数据
    // 直接存为 Data 而非文件路径，避免文件管理复杂性
    // 小图压缩后存储（~200KB以内），预览用缩略图
    // ============================================

    // 原始图片数据（压缩后的 JPEG）
    @Attribute(.externalStorage) var imageData: Data?

    // 缩略图数据（用于列表展示，降低内存占用）
    @Attribute(.externalStorage) var thumbnailData: Data?

    // ============================================
    // 颜色用量 - 与 BeadColor 的一对多关系
    // 每张图纸记录了使用了哪些颜色、各用了多少粒
    // ============================================

    // 图纸包含的颜色用量列表
    @Relationship(deleteRule: .cascade) var colorUsages: [ProjectColorUsage]

    // ============================================
    // 初始化
    // ============================================

    init(
        id: UUID = UUID(),
        name: String,
        status: ProjectStatus = .notStarted,
        note: String = "",
        imageData: Data? = nil,
        thumbnailData: Data? = nil,
        colorUsages: [ProjectColorUsage] = []
    ) {
        self.id = id
        self.name = name
        self.status = status.rawValue
        self.note = note
        self.imageData = imageData
        self.thumbnailData = thumbnailData
        self.colorUsages = colorUsages
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // ============================================
    // 便捷属性
    // ============================================

    // 获取枚举状态
    var statusEnum: ProjectStatus {
        get { ProjectStatus(rawValue: status) ?? .notStarted }
        set { status = newValue.rawValue }
    }

    // 图片压缩质量（0 ~ 1）
    static let imageCompressionQuality: CGFloat = 0.7
    // 缩略图最大边长
    static let thumbnailSize: CGFloat = 200
}
