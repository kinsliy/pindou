import SwiftData
import SwiftUI

// ============================================
// ProjectDetailView - 图纸详情页
// 查看图纸的完整信息，支持状态变更和扣减库存
// ============================================

struct ProjectDetailView: View {
    // ============================================
    // SwiftData 依赖注入
    // ============================================
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // ============================================
    // Props
    // ============================================

    let project: Project

    // ============================================
    // 状态变量
    // ============================================

    @State private var showingEditor = false
    @State private var alertMessage: String?
    @State private var confirmDelete = false

    // ============================================
    // View 主体
    // ============================================

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 图片
                imageSection

                // 基本信息
                infoSection

                // 状态切换
                statusSection

                // 颜色用量列表
                colorUsageSection

                // 操作按钮
                actionButtons
            }
            .padding(18)
        }
        .background(Color(red: 0.97, green: 0.98, blue: 1.0))
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("编辑") { showingEditor = true }
            }
        }
        .fullScreenCover(isPresented: $showingEditor) {
            ProjectEditorView(mode: .edit, existingProject: project)
        }
        .alert("提示", isPresented: Binding(
            get: { alertMessage != nil },
            set: { _ in alertMessage = nil }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
        .alert("确认删除", isPresented: $confirmDelete) {
            Button("删除", role: .destructive) { deleteProject() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后将无法恢复。如果图纸已完成，已扣除的库存不会恢复。")
        }
    }

    // ============================================
    // 子视图
    // ============================================

    // 图片区域
    private var imageSection: some View {
        Group {
            if let imageData = project.imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 350)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(.black.opacity(0.1)))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // 基本信息
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(project.name)
                .font(.title2.bold())

            if !project.note.isEmpty {
                Text(project.note)
                    .font(.body)
                    .foregroundStyle(.black.opacity(0.65))
            }

            HStack(spacing: 16) {
                Label("\(project.colorUsages.count) 种颜色", systemImage: "paintpalette")
                    .font(.caption)
                    .foregroundStyle(.black.opacity(0.5))
                Label("创建 \(project.createdAt.formatted(date: .abbreviated, time: .shortened))", systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.black.opacity(0.5))
            }
        }
    }

    // 状态切换
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("状态")
                .font(.headline)
                .foregroundStyle(.black.opacity(0.7))

            // 分段选择器风格的按钮组
            HStack(spacing: 0) {
                ForEach(ProjectStatus.allCases) { status in
                    Button {
                        changeStatus(to: status)
                    } label: {
                        Text(status.rawValue)
                            .font(.subheadline.weight(.medium))
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(project.statusEnum == status ? Color.indigo : Color.white)
                            .foregroundStyle(project.statusEnum == status ? Color.white : Color.black.opacity(0.6))
                    }
                    .buttonStyle(.plain)

                    if status != ProjectStatus.allCases.last {
                        Divider()
                            .frame(width: 1)
                            .background(Color.black.opacity(0.12))
                    }
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black.opacity(0.2)))
        }
    }

    // 颜色用量列表
    private var colorUsageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("颜色用量")
                .font(.headline)
                .foregroundStyle(.black.opacity(0.7))

            if project.colorUsages.isEmpty {
                Text("暂未记录颜色用量")
                    .font(.subheadline)
                    .foregroundStyle(.black.opacity(0.4))
            } else {
                VStack(spacing: 8) {
                    ForEach(project.colorUsages) { usage in
                        if let color = usage.color {
                            HStack(spacing: 12) {
                                // 色块
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(color.color)
                                    .frame(width: 36, height: 36)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.black.opacity(0.12)))

                                // 色号信息
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(color.code)
                                        .font(.subheadline.weight(.medium))
                                    Text(color.series)
                                        .font(.caption)
                                        .foregroundStyle(.black.opacity(0.45))
                                }

                                Spacer()

                                // 用量
                                Text("\(usage.count) 粒")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.black.opacity(0.7))
                            }
                            .padding(10)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.black.opacity(0.08)))
                        }
                    }
                }
            }

            // 总计
            if !project.colorUsages.isEmpty {
                HStack {
                    Spacer()
                    Text("合计 \(project.colorUsages.reduce(0) { $0 + $1.count }) 粒")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.black.opacity(0.5))
                }
            }
        }
    }

    // 操作按钮
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // 完成并扣减库存
            if project.statusEnum != .completed {
                Button {
                    completeAndDeductStock()
                } label: {
                    Label("标记完成并扣减库存", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.green)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }

            // 删除图纸
            Button(role: .destructive) {
                confirmDelete = true
            } label: {
                Label("删除图纸", systemImage: "trash")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(.red.opacity(0.4)))
            }
            .buttonStyle(.plain)
        }
    }

    // ============================================
    // 方法
    // ============================================

    // 更改状态
    private func changeStatus(to newStatus: ProjectStatus) {
        project.statusEnum = newStatus
        project.updatedAt = Date()
        try? modelContext.save()
    }

    // 标记完成并扣减库存
    private func completeAndDeductStock() {
        // 1. 检查库存是否充足
        var insufficientColors: [String] = []
        for usage in project.colorUsages {
            if let color = usage.color {
                if color.stockCount < usage.count {
                    insufficientColors.append("\(color.code)（需要 \(usage.count) 粒，库存 \(color.stockCount) 粒）")
                }
            }
        }

        if !insufficientColors.isEmpty {
            alertMessage = "库存不足，无法扣减：\n" + insufficientColors.joined(separator: "\n")
            return
        }

        // 2. 扣减库存
        for usage in project.colorUsages {
            if let color = usage.color {
                color.stockCount -= usage.count
            }
        }

        // 3. 更新状态和Save
        project.statusEnum = .completed
        project.updatedAt = Date()
        try? modelContext.save()

        alertMessage = "已完成！已从豆仓扣减 \(project.colorUsages.reduce(0) { $0 + $1.count }) 粒豆子。"
    }

    // 删除图纸
    private func deleteProject() {
        modelContext.delete(project)
        try? modelContext.save()
        dismiss()
    }
}
