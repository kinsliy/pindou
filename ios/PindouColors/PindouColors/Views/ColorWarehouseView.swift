import SwiftData
import SwiftUI
import UniformTypeIdentifiers

// ============================================
// ColorSortMode - 排序模式枚举
// 类似于前端的 TypeScript 枚举或常量定义
// ============================================

enum ColorSortMode: String, CaseIterable, Identifiable {
    case `default` = "默认"           // 按系统默认顺序排序
    case lowStock = "由少到多"        // 按库存升序
    case highStock = "由多到少"       // 按库存降序

    // Identifiable 协议要求：每个枚举 case 都有唯一 id
    var id: String { rawValue }
}

// ============================================
// ColorWarehouseView - 豆仓（颜色仓库）主页面
// 类似于前端 React/Vue 的页面组件
// 功能：显示所有颜色、管理库存、搜索筛选
// ============================================

struct ColorWarehouseView: View {
    // ============================================
    // SwiftData 依赖注入 - 类似于前端的全局状态管理
    // @Environment 获取祖先节点提供的环境值
    // modelContext 类似于 Redux store 或 Vuex
    // ============================================
    @Environment(\.modelContext) private var modelContext

    // @Query 从 SwiftData 数据库查询数据
    // 类似于前端的 useQuery / useSelector 自动订阅数据
    // sort: 指定排序规则，类似 SQL 的 ORDER BY
    @Query(sort: [
        SortDescriptor(\BeadColor.series),        // 先按系列排序
        SortDescriptor(\BeadColor.sortOrder),   // 再按顺序排序
        SortDescriptor(\BeadColor.code)          // 最后按色号排序
    ])
    private var colors: [BeadColor]              // 所有颜色数据，类似 useState

    // ============================================
    // 状态变量 - 类似于前端的 useState
    // 这些变量变化时会触发 UI 更新
    // ============================================

    @State private var searchText = ""           // 搜索关键词
    @State private var selectedSeries = "全部"    // 当前选中的系列
    @State private var sortMode: ColorSortMode = .default  // 排序模式
    @State private var showsGrid = true          // 是否显示网格视图（vs 列表视图）
    @State private var editingColor: BeadColor?  // 当前编辑的颜色（用于弹窗）
    @State private var isCreatingColor = false  // 是否在创建新颜色
    @State private var isImporting = false       // 是否显示导入弹窗
    @State private var isSyncing = false         // 是否正在同步（加载状态）
    @State private var alertMessage: String?     // 提示信息内容
    @State private var exportDocument = ExportDocument()  // 导出文档对象
    @State private var exportFileName = "pindou-colors.json"  // 导出文件名
    @State private var isExporting = false       // 是否正在导出
    @State private var didAttemptInitialSync = false  // 是否已尝试初始同步

    // ============================================
    // 服务类实例 - 类似于前端的 API 服务层
    // ============================================

    private let seedService = DefaultColorSeedService()   // 种子数据服务
    private let backupService = BackupService()           // 备份服务

    // ============================================
    // View 的主体 - 相当于前端的 return JSX / render
    // ============================================

    var body: some View {
        // NavigationStack 相当于前端的路由容器
        // 提供导航栏、标题等 UI 框架，类似 React Router 的 Router
        NavigationStack {
            ZStack {
                // 背景渐变 - 类似于前端的 CSS 渐变背景
                LinearGradient(
                    colors: [
                        Color(red: 0.97, green: 0.98, blue: 1.0),  // 浅蓝
                        Color(red: 0.91, green: 0.97, blue: 1.0)   // 更浅的蓝
                    ],
                    startPoint: .top,   // 渐变起点
                    endPoint: .bottom   // 渐变终点
                )
                .ignoresSafeArea()  // 延伸到屏幕边缘，类似 CSS 的 position: fixed

                // ScrollView 垂直滚动容器 - 相当于前端的 <ScrollView> 或 overflow-y: auto
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 18) {
                        // 页面头部
                        header
                        // 统计摘要
                        summaryBand
                        // 搜索框
                        searchField
                        // 系列筛选标签
                        seriesChips
                        // 工具栏（排序、导入导出等）
                        toolbar
                        // 颜色列表/网格内容
                        groupedContent
                    }
                    .padding(.horizontal, 18)  // 水平内边距，类似 CSS 的 padding: 0 18px
                    .padding(.bottom, 28)     // 底部内边距
                }
                .scrollBounceBehavior(.basedOnSize)  // 滚动回弹行为
            .scrollDismissesKeyboard(.immediately)  /* 滚动时收起键盘 */
            }
            // 隐藏导航栏 - 因为我们是自定义头部
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)

            // ============================================
            // 弹窗配置 - 类似于前端的 Modal / Dialog
            // ============================================

            // 编辑颜色弹窗 - .sheet 类似前端的可控弹窗
            .sheet(item: $editingColor) { color in
                ColorEditorView(color: color)
                    // .presentationDetents 设置弹窗高度
                    // 类似前端的 Modal 高度配置
                    .presentationDetents([.medium, .large])
            }

            // 新建颜色弹窗
            .sheet(isPresented: $isCreatingColor) {
                ColorEditorView(color: nil)
                    .presentationDetents([.medium, .large])
            }

            // 导入弹窗
            .sheet(isPresented: $isImporting) {
                ImportSheetView(existingColors: colors) { result in
                    // 导入完成回调，类似前端的 onComplete
                    alertMessage = "导入完成：新增 \(result.inserted)，更新 \(result.updated)"
                }
            }

            // 文件导出器 - iOS 原生的文件保存对话框
            .fileExporter(
                isPresented: $isExporting,
                document: exportDocument,
                // contentType 根据文件扩展名确定文件类型
                contentType: exportFileName.hasSuffix(".csv") ? .commaSeparatedText : .json,
                defaultFilename: exportFileName
            ) { result in
                // 导出完成回调
                if case .failure(let error) = result {
                    alertMessage = error.localizedDescription
                }
            }

            // 警告提示弹窗 - 类似于前端的 Alert / Toast
            .alert("提示", isPresented: Binding(
                get: { alertMessage != nil },
                set: { _ in alertMessage = nil }
            )) {
                Button("好", role: .cancel) {}
            } message: {
                Text(alertMessage ?? "")
            }

            // .task 类似前端的 useEffect，在视图出现时执行
            .task {
                await seedDefaultColorsIfNeeded()
            }
        }
    }

    // ============================================
    // 子视图 - 类似于前端的子组件拆分
    // 使用 private var 声明，类似 React 的 const Header = () => {}
    // ============================================

    // 页面头部区域
    private var header: some View {
        HStack(alignment: .bottom) {  // HStack = 水平布局，类似 flex-direction: row
            VStack(alignment: .leading, spacing: 4) {  // VStack = 垂直布局
                Text("我的豆仓")
                    .font(.system(size: 30, weight: .black))  // 字体大小和粗细
                    .foregroundStyle(.black.opacity(0.9))  // 黑色，确保在浅色背景上清晰可见
                Text("颜色、库存和导入备份")
                    .font(.footnote)   // 小字体
                    .foregroundStyle(.black.opacity(0.7))  /* 加深，确保在白底上可读 */  // 次要颜色，更深一点
            }
            Spacer()  // 弹性空间，类似 CSS 的 flex: 1

            // 按钮 - 类似于前端的 <button> 或 <Button>
            Button {
                isCreatingColor = true
            } label: {
                Label("补豆入库", systemImage: "plus.circle")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)  // 按钮样式：填充样式
            .buttonBorderShape(.capsule)     // 胶囊形状
        }
        .padding(.top, 18)
    }

    // 统计摘要条
    private var summaryBand: some View {
        HStack(spacing: 12) {
            Text("总库存")
                .font(.headline)
                .foregroundStyle(.black.opacity(0.85))  // 深色文字确保可见
            Text("\(totalStock.formatted()) 粒 · \(filteredColors.count) 色号")
                .font(.headline)
                .foregroundStyle(.black.opacity(0.85))  // 深色文字确保在白色背景上可见
                .padding(.horizontal, 18)   // 水平内边距
                .padding(.vertical, 10)     // 垂直内边距
                .background(.white)         // 白色背景
                .clipShape(Capsule())       // 胶囊形状裁剪
                .overlay(Capsule().stroke(.black.opacity(0.2)))  /* 加深边框，使白色胶囊可见 */
            Spacer()
        }
    }

    // 搜索框
    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.title3)              // 系统图标
                .foregroundStyle(.black.opacity(0.65))  /* 加深，确保可见 */  // 深色图标确保可见
            TextField("搜索色号", text: $searchText, prompt: Text("搜索色号").foregroundStyle(.black.opacity(0.6))  /* 加深，确保可见 */)
                .textInputAutocapitalization(.characters)  // 自动大写
                .autocorrectionDisabled()   // 禁用自动纠错
                .foregroundStyle(.black.opacity(0.9))  // 深色输入文字确保可见
        }
        .padding(16)
        .background(.white.opacity(0.95))  // 更不透明的白色背景
        .clipShape(RoundedRectangle(cornerRadius: 8))  // 圆角矩形
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.black.opacity(0.25)))  /* 加深边框 */
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }  /* 键盘上方"完成"按钮，点击收起键盘 */
    }

    // 系列筛选标签横向滚动区域
    private var seriesChips: some View {
        // ScrollView 横向滚动 - 类似于前端的 <ScrollView horizontal>
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // "全部" 标签
                chip("slider.horizontal.3", "全部", isActive: selectedSeries == "全部") {
                    selectedSeries = "全部"
                }
                // 动态生成的系列标签
                ForEach(series, id: \.self) { item in
                    chip(nil, item, isActive: selectedSeries == item) {
                        selectedSeries = item
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    // 工具栏
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
            .buttonStyle(PillButtonStyle(active: true))

            // 补齐 291 色按钮
            Button {
                Task { await seedMissingDefaultColors(showAlert: true) }
            } label: {
                Label(isSyncing ? "准备中" : "补齐 291 色", systemImage: "square.grid.3x3")
            }
            .buttonStyle(PillButtonStyle(active: false))
            .disabled(isSyncing)

            Spacer()

            // 更多操作菜单（导入导出）
            Menu {
                Button("粘贴 HTML 导入") { isImporting = true }
                Button("导出 JSON") { exportJSON() }
                Button("导出 CSV") { exportCSV() }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)

            // 切换视图模式按钮
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
        VStack(alignment: .leading, spacing: 16) {
            // 按系列分组展示
            ForEach(groupedSeries, id: \.series) { group in
                VStack(alignment: .leading, spacing: 12) {
                    // 系列标题
                    HStack {
                        Text("\(group.series) 系列")
                            .font(.title2.bold())
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("\(group.items.count) 色号 · \(group.items.reduce(0) { $0 + $1.stockCount }.formatted()) 粒")
                            .font(.subheadline)
                            .foregroundStyle(.black.opacity(0.65))  /* 加深，确保在白底上可读 */
                    }

                    // 根据视图模式显示网格或列表
                    if showsGrid {
                        // 网格视图 - LazyVGrid 类似前端的 Grid 布局
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible()),  // 两列，每列等宽
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
                        // 列表视图
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

            // 空状态 - 类似于前端的 Empty 组件
            if filteredColors.isEmpty {
                ContentUnavailableView(
                    "暂无颜色",
                    systemImage: "paintpalette",
                    description: Text("默认 291 色会自动准备，也可以手动新增。")
                )
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            }
        }
    }

    // ============================================
    // 工具方法 - 类似于前端的 helper 函数
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
            .background(isActive ? Color.indigo : .white)  // 激活状态紫色，非激活白色
            .foregroundStyle(isActive ? .white : .black.opacity(0.85))  // 非激活状态深色文字确保可见
            .clipShape(Capsule())
            .overlay(Capsule().stroke(.black.opacity(0.25)))  /* 加深边框，使白色按钮可见 */
        }
        .buttonStyle(.plain)
    }

    // 获取所有系列列表
    private var series: [String] {
        // Set 去重，类似于前端的 [...new Set()]
        Array(Set(colors.map(\.series))).sorted()
    }

    // 过滤后的颜色列表
    // 类似于前端的 useMemo / computed 属性
    private var filteredColors: [BeadColor] {
        // 搜索关键词处理
        let query = searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        // 过滤逻辑 - 链式筛选，类似前端的 array.filter().filter()
        var result = colors.filter { color in
            // 系列匹配
            let matchesSeries = selectedSeries == "全部" || color.series == selectedSeries
            // 搜索匹配（色号、hex、名称、别名）
            let matchesSearch = query.isEmpty ||
                color.code.lowercased().contains(query) ||
                color.hex.lowercased().contains(query) ||
                color.displayName.lowercased().contains(query) ||
                color.alias.lowercased().contains(query)
            return matchesSeries && matchesSearch
        }

        // 排序处理
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
        // Dictionary(grouping:by:) 类似前端的 lodash.groupBy
        Dictionary(grouping: filteredColors, by: \.series)
            .map { ($0.key, $0.value) }
            .sorted { $0.0 < $1.0 }
    }

    // 计算总库存
    private var totalStock: Int {
        colors.reduce(0) { $0 + $1.stockCount }
        // reduce 类似前端的 array.reduce((acc, item) => acc + item.stockCount, 0)
    }

    // ============================================
    // 异步方法 - 类似于前端的 async/await 函数
    // ============================================

    // 补齐缺失的默认颜色
    @MainActor  // 在主线程执行，类似前端的 runOnUIThread
    private func seedMissingDefaultColors(showAlert: Bool) async {
        isSyncing = true
        defer { isSyncing = false }  // finally 块，确保最终重置状态

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

    // 初始化时检查是否需要同步
    @MainActor
    private func seedDefaultColorsIfNeeded() async {
        // 如果已有数据或已尝试同步，则跳过
        guard !didAttemptInitialSync, colors.isEmpty else {
            return
        }
        didAttemptInitialSync = true
        await seedMissingDefaultColors(showAlert: false)
    }

    // 导出 JSON
    private func exportJSON() {
        do {
            exportDocument = ExportDocument(data: try backupService.exportJSON(colors: colors))
            exportFileName = "pindou-colors.json"
            isExporting = true
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    // 导出 CSV
    private func exportCSV() {
        exportDocument = ExportDocument(data: backupService.exportCSV(colors: colors))
        exportFileName = "pindou-colors.csv"
        isExporting = true
    }
}

// ============================================
// PillButtonStyle - 胶囊按钮样式
// 类似于前端的 CSS class 或 styled-components
// ============================================

struct PillButtonStyle: ButtonStyle {
    var active: Bool  // 是否激活状态

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(active ? Color.indigo : Color.white)
            .foregroundStyle(active ? .white : .primary)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(.black.opacity(0.2)))  /* 加深边框，使白色按钮可见 */
            // 按下时缩小，类似于 CSS 的 :active transform
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}
