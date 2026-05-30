import Foundation
import SwiftData

// ============================================
// ProjectColorUsage - 图纸颜色用量模型
// 记录一张图纸使用了哪个颜色、用了多少粒
// 类似前端的关联表（junction table）
// ============================================

@Model
final class ProjectColorUsage {
    // ============================================
    // 属性
    // ============================================

    // 唯一标识符
    @Attribute(.unique) var id: UUID

    // 关联的颜色（指向豆仓中的 BeadColor）
    var color: BeadColor?

    // 该颜色在图纸中的用量（粒数）
    var count: Int

    // 所属的图纸（反向关系）
    var project: Project?

    // ============================================
    // 初始化
    // ============================================

    init(
        id: UUID = UUID(),
        color: BeadColor? = nil,
        count: Int = 0,
        project: Project? = nil
    ) {
        self.id = id
        self.color = color
        self.count = count
        self.project = project
    }
}
