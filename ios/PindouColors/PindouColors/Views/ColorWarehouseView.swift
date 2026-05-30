import SwiftData
import SwiftUI
import UniformTypeIdentifiers

// ============================================
// ColorSortMode - 排序模式枚举
// ============================================

enum ColorSortMode: String, CaseIterable, Identifiable {
    case `default` = "默认"
    case lowStock = "由少到多"
    case highStock = "由多到多"

    var id: String { rawValue }
}


// ============================================
// ColorMode - 颜色范围模式枚举
// 221 色基础版（A~M）或 291 色完整版（全部系列）
// ============================================

enum ColorMode: String, CaseIterable, Identifiable {
    case basic = "221色 基础版"
    case full = "291色 完整版"

    var id: String { rawValue }

    // 221 色模式允许的系列（A~M 共9个系列）
    var allowedSeries: [String] {
        switch self {
        case .basic:
            return ["A", "B", "C", "D", "E", "F", "G", "H", "M"]
        case .full:
            return []  // 空数组 = 不过滤，显示全部
        }
    }

}

// ============================================
// ColorWarehouseView - 豆仓（颜色仓库）主页面
// ============================================

struct ColorWarehouseView: View {
    // ============================================
    // SwiftData 依赖注入
    // ============================================
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [
        SortDescriptor(\BeadColor.series),
        SortDescriptor(\BeadColor.sortOrder),
        SortDescriptor(\BeadColor.code)
    ])
    private var colors: [BeadColor]

    // ============================================
    // 状态变量
    // ============================================

    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool  // 搜索框焦点，用于控制键盘收起
    @State private var selectedSeries = "全部"
    @State private var colorMode: ColorMode = .full

    @State private var sortMode: ColorSortMode = .default
    @State private var showsGrid = true
    @State private var editingColor: BeadColor?
    @State private var isCreatingColor = false
    @State private var isSyncing = false
    @State private var alertMessage: String?
    @State private var didAttemptInitialSync = false

    // ============================================
    // 服务类
    // ============================================

    private let seedService = DefaultColorSeedService()

    // ============================================
    // View 主体
    // ============================================

    var body: some View {
        NavigationStack {
            content
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(.hidden, for: .navigationBar)
                // 弹窗和导出
                .sheet(item: $editingColor) { color in
                    ColorEditorView(color: color)
                }
                .sheet(isPresented: $isCreatingColor) {
                    ColorEditorView(color: nil)
                }
                .alert("提示", isPresented: Binding(
                    get: { alertMessage != nil },
                    set: { _ in alertMessage = nil }
                )) {
                    Button("好", role: .cancel) {}
                } message: {
                    Text(alertMessage ?? "")
                }
                .task {
                    await seedDefaultColorsIfNeeded()
                }
        }
    }

    // ============================================
    // 主内容区域 - 拆分出来使 toolbar 修饰符正确作用域
    // ============================================

    @ViewBuilder
    private var content: some View {
        ZStack(alignment: .top) {
            // 背景 - 保持渐变但添加白色底色确保内容区域始终可读
            LinearGradient(
                colors: [
                    Color(red: 0.97, green: 0.98, blue: 1.0),
                    Color(red: 0.91, green: 0.97, blue: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    summaryBand
                    searchField
                    colorModePicker

                    seriesChips
                    toolbar
                    groupedContent
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.immediately)
        }
    }

    // ============================================
    // 子视图
    // ============================================

    // 页面头部
    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text("我的豆仓")
                    .font(.system(size: 30, weight: .black))
                    .foregroundStyle(.black.opacity(0.9))
            }
            Spacer()

            Button {
                isCreatingColor = true
            } label: {
                Label("补豆入库", systemImage: "plus.circle")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
        }
        .padding(.top, 18)
    }

    // 统计摘要条
    private var summaryBand: some View {
        HStack(spacing: 12) {
            Text("总库存")
                .font(.headline)
                .foregroundStyle(.black.opacity(0.85))
            Text("\(totalStock.formatted()) 粒 · \(filteredColors.count) 色号")
                .font(.headline)
                .foregroundStyle(.black.opacity(0.85))
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(.white)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(.black.opacity(0.2)))  // 确保白色胶囊在浅色背景上也可见
            Spacer()
        }
    }

    // 搜索框
    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.title3)
                .foregroundStyle(.black.opacity(0.65))
            TextField("搜索色号", text: $searchText, prompt: Text("搜索色号").foregroundStyle(.black.opacity(0.6)))
                .focused($isSearchFocused)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .foregroundStyle(.black.opacity(0.9))
        }
        .padding(16)
        .background(.white.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.black.opacity(0.25)))
        .contentShape(Rectangle())
        .onTapGesture { isSearchFocused = true }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
    }
    // 系列筛选标签横向滚动区域
    // ============================================
    // colorModePicker - 221色/291色切换按钮
    // 仿网站设计：两个并排的胶囊按钮
    // ============================================

    private var colorModePicker: some View {
        HStack(spacing: 0) {
            ForEach(ColorMode.allCases) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        colorMode = mode
                        // 切换模式时重置系列筛选
                        selectedSeries = "全部"
                    }
                } label: {
                    VStack(spacing: 2) {
                        Text(mode.rawValue)
                            .font(.headline.weight(.bold))
                        Text(mode == .basic ? "A~M 共9系列" : "含P/Q/R/T/Y/ZG共15系列")
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(colorMode == mode ? Color.indigo : Color.white)
                    .foregroundStyle(colorMode == mode ? Color.white : Color.black.opacity(0.7))
                }
                .buttonStyle(.plain)

                // 在两个按钮之间加分隔线
                if mode != ColorMode.allCases.last {
                    Divider()
                        .frame(width: 1)
                        .background(Color.black.opacity(0.15))
                }
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black.opacity(0.2)))
    }


    // 系列筛选标签横向滚动区域

    private var seriesChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                chip("slider.horizontal.3", "全部 (\(filteredCount))", isActive: selectedSeries == "全部") {
                    selectedSeries = "全部"
                }
                ForEach(series, id: \.self) { item in
                    chip(nil, item, isActive: selectedSeries == item) {
                        selectedSeries = item
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    // 工具栏（排序、视图切换）
    // 补齐按钮和导入导出已移除 — 移到"设置"tab
    private var toolbar: some View {
        HStack(spacing: 12) {
            // 排序菜单
            Menu {
                Picker("排序", selection: $sortMode) {
                    ForEach(ColorSortMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
            } label: {
                Label(sortMode.rawValue, systemImage: "arrow.up.arrow.down")
            }

            Spacer()

            // 视图切换按钮
            Button {
                showsGrid.toggle()
            } label: {
                Image(systemName: showsGrid ? "list.bullet" : "square.grid.2x2")
                    .font(.title3)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.circle)
        }
    }

    // 颜色分组列表/网格
    private var groupedContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            ForEach(groupedSeries, id: \.series) { group in
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("\(group.series) 系列")
                            .font(.title2.bold())
                            .foregroundStyle(.indigo)
                        Spacer()
                        Text("\(group.items.count) 色号 · \(group.items.reduce(0) { $0 + $1.stockCount }.formatted()) 粒")
                            .font(.subheadline)
                            .foregroundStyle(.black.opacity(0.65))
                    }

                    if showsGrid {
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ],
                            spacing: 14
                        ) {
                            ForEach(group.items) { color in
                                ColorCardView(color: color) {
                                    editingColor = color
                                }
                            }
                        }
                    } else {
                        VStack(spacing: 10) {
                            ForEach(group.items) { color in
                                ColorCardView(color: color, isCompact: true) {
                                    editingColor = color
                                }
                            }
                        }
                    }
                }
            }

            if filteredColors.isEmpty {
                ContentUnavailableView(
                    "暂无颜色",
                    systemImage: "paintpalette",
                    description: Text(colorMode == .basic ? "当前为 221 色模式，默认 A~M 系列会自动准备。" : "默认 291 色会自动准备，也可以手动新增。")
                )
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            }
        }
    }

    // ============================================
    // 工具方法
    // ============================================

    // 创建筛选标签按钮
    private func chip(_ systemImage: String?, _ title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .font(.headline)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            // 背景色加厚：非激活状态从 4% → 8%，使 chips 在白色底色上也明显可见
            .background(isActive ? Color.indigo : .black.opacity(0.08))
            .foregroundStyle(isActive ? .white : .black.opacity(0.85))
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(.black.opacity(0.25)))
        }
        .buttonStyle(.plain)
    }

    // 获取所有系列列表
    private var series: [String] {
        let allSeries = Set(colors.map(\.series))
        if colorMode == .full {
            return allSeries.sorted()
        }
        return allSeries.filter { colorMode.allowedSeries.contains($0) }.sorted()
    }

    // 当前模式下的颜色总数（用于全部标签的显示）
    private var filteredCount: Int {
        colors.filter { color in
            let matchesMode = colorMode == .full || colorMode.allowedSeries.contains(color.series)
            return matchesMode
        }.count
    }


    // 过滤后的颜色列表
    private var filteredColors: [BeadColor] {
        let query = searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        var result = colors.filter { color in
            let matchesMode = colorMode == .full || colorMode.allowedSeries.contains(color.series)
            let matchesSeries = selectedSeries == "全部" || color.series == selectedSeries
            let matchesSearch = query.isEmpty ||
                color.code.lowercased().contains(query) ||
                color.hex.lowercased().contains(query) ||
                color.displayName.lowercased().contains(query) ||
                color.alias.lowercased().contains(query)
            return matchesMode && matchesSeries && matchesSearch
        }

        switch sortMode {
        case .default:
            result.sort { lhs, rhs in
                if lhs.series != rhs.series { return lhs.series < rhs.series }
                if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
                return lhs.code.localizedStandardCompare(rhs.code) == .orderedAscending
            }
        case .lowStock:
            result.sort { $0.stockCount < $1.stockCount }
        case .highStock:
            result.sort { $0.stockCount > $1.stockCount }
        }
        return result
    }

    // 按系列分组
    private var groupedSeries: [(series: String, items: [BeadColor])] {
        Dictionary(grouping: filteredColors, by: \.series)
            .map { ($0.key, $0.value) }
            .sorted { $0.0 < $1.0 }
    }

    // 计算总库存
    private var totalStock: Int {
        filteredColors.reduce(0) { $0 + $1.stockCount }
    }

    // ============================================
    // 异步方法
    // ============================================

    @MainActor
    private func seedMissingDefaultColors(showAlert: Bool) async {
        isSyncing = true
        defer { isSyncing = false }

        do {
            let result = try seedService.insertMissingDefaults(
                into: modelContext,
                existingColors: colors
            )
            if showAlert {
                alertMessage = "默认 291 色已补齐：新增 \(result.inserted)，保留已有 \(result.skipped)"
            }
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    @MainActor
    private func seedDefaultColorsIfNeeded() async {
        guard !didAttemptInitialSync, colors.isEmpty else {
            return
        }
        didAttemptInitialSync = true
        await seedMissingDefaultColors(showAlert: false)
    }
}

// ============================================
// PillButtonStyle - 胶囊按钮样式
// ============================================

struct PillButtonStyle: ButtonStyle {
    var active: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            // 非激活状态背景从 4% → 8%，确保在白色底色上也可见
            .background(active ? Color.indigo : .black.opacity(0.08))
            .foregroundStyle(active ? .white : .primary)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(.black.opacity(0.2)))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}
