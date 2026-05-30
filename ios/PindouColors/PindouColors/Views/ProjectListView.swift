import SwiftData
import SwiftUI
import PhotosUI

// ============================================
// ProjectListView - 图纸册主页面
// 展示所有图纸的列表，支持新建和搜索
// ============================================

struct ProjectListView: View {
    // ============================================
    // SwiftData 依赖注入
    // ============================================
    @Environment(\.modelContext) private var modelContext

    // 按更新时间倒序获取所有图纸
    @Query(sort: [SortDescriptor(\Project.updatedAt, order: .reverse)])
    private var projects: [Project]

    // ============================================
    // 状态变量
    // ============================================

    @State private var searchText = ""
    @State private var showingNewProject = false
    @FocusState private var isSearchFocused: Bool  // 搜索框焦点，用于控制键盘收起

    // ============================================
    // View 主体
    // ============================================

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // 背景
                LinearGradient(
                    colors: [
                        Color(red: 0.97, green: 0.98, blue: 1.0),
                        Color(red: 0.91, green: 0.97, blue: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                // 点击背景收起键盘
                .onTapGesture {
                    isSearchFocused = false
                }

                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        searchField
                        projectGrid
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 28)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollDismissesKeyboard(.immediately)
            }
            // 新建图纸弹窗
            .fullScreenCover(isPresented: $showingNewProject) {
                ProjectEditorView(mode: .create)
            }
            // 查看/编辑图纸
            .navigationDestination(isPresented: .constant(false)) {
                // 用另一种方式处理导航
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") {
                        isSearchFocused = false
                    }
                }
            }
        }
    }

    // ============================================
    // 子视图
    // ============================================

    // 页面头部
    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text("图纸册")
                    .font(.system(size: 30, weight: .black))
                    .foregroundStyle(.black.opacity(0.9))
                Text("\(projects.count) 张图纸")
                    .font(.subheadline)
                    .foregroundStyle(.black.opacity(0.55))
            }
            Spacer()

            // 新建图纸
            Button {
                showingNewProject = true
            } label: {
                Label("新建图纸", systemImage: "plus.circle")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
        }
        .padding(.top, 18)
    }

    // 搜索框
    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.title3)
                .foregroundStyle(.black.opacity(0.65))
            TextField("搜索图纸", text: $searchText, prompt: Text("搜索图纸").foregroundStyle(.black.opacity(0.6)))
                .focused($isSearchFocused)
                .submitLabel(.done)
                .onSubmit {
                    // 按键盘 return/done 收起键盘
                    isSearchFocused = false
                }
                .autocorrectionDisabled()
                .foregroundStyle(.black.opacity(0.9))
        }
        .padding(16)
        .background(.white.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.black.opacity(0.25)))
        .contentShape(Rectangle())
        .onTapGesture {
            isSearchFocused = true
        }
    }

    // 图纸网格
    @ViewBuilder
    private var projectGrid: some View {
        let filtered = filteredProjects

        if filtered.isEmpty {
            ContentUnavailableView(
                "暂无图纸",
                systemImage: "book.pages",
                description: Text("点击右上角新建按钮创建第一张图纸。")
            )
            .frame(maxWidth: .infinity)
            .foregroundStyle(.black.opacity(0.45))
            .padding(.top, 40)
        } else {
            LazyVGrid(
                columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ],
                spacing: 16
            ) {
                ForEach(filtered) { project in
                    NavigationLink(value: project) {
                        ProjectCardView(project: project)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // ============================================
    // 计算属性
    // ============================================

    // 搜索过滤后的图纸
    private var filteredProjects: [Project] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty {
            return projects
        }
        return projects.filter { project in
            project.name.lowercased().contains(query) ||
            project.note.lowercased().contains(query)
        }
    }
}

// ============================================
// ProjectCardView - 图纸卡片组件
// 展示封面缩略图、名称、状态、颜色数量
// ============================================

struct ProjectCardView: View {
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 封面图
            Group {
                if let thumbnailData = project.thumbnailData,
                   let uiImage = UIImage(data: thumbnailData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    // 无图占位
                    ZStack {
                        Rectangle()
                            .fill(Color.black.opacity(0.06))
                        Image(systemName: "photo.badge.plus")
                            .font(.largeTitle)
                            .foregroundStyle(.black.opacity(0.3))
                    }
                }
            }
            .frame(height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.black.opacity(0.1)))

            // 名称
            Text(project.name)
                .font(.headline)
                .foregroundStyle(.black.opacity(0.85))
                .lineLimit(1)

            // 状态 + 颜色数
            HStack {
                // 状态标签
                Text(project.statusEnum.rawValue)
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(statusColor.opacity(0.15))
                    .foregroundStyle(statusColor)
                    .clipShape(Capsule())

                Spacer()

                // 颜色数
                Text("\(project.colorUsages.count) 色")
                    .font(.caption)
                    .foregroundStyle(.black.opacity(0.5))
            }
        }
        .padding(12)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }

    // 状态对应的颜色
    private var statusColor: Color {
        switch project.statusEnum {
        case .notStarted: return .orange
        case .inProgress: return .blue
        case .completed:  return .green
        }
    }
}
