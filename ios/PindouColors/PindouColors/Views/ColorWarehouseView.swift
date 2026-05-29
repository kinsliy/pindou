import SwiftData
import SwiftUI
import UniformTypeIdentifiers

enum ColorSortMode: String, CaseIterable, Identifiable {
    case `default` = "默认"
    case lowStock = "由少到多"
    case highStock = "由多到少"

    var id: String { rawValue }
}

struct ColorWarehouseView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\BeadColor.series), SortDescriptor(\BeadColor.sortOrder), SortDescriptor(\BeadColor.code)])
    private var colors: [BeadColor]

    @State private var searchText = ""
    @State private var selectedSeries = "全部"
    @State private var sortMode: ColorSortMode = .default
    @State private var showsGrid = true
    @State private var editingColor: BeadColor?
    @State private var isCreatingColor = false
    @State private var isImporting = false
    @State private var isSyncing = false
    @State private var alertMessage: String?
    @State private var exportDocument = ExportDocument()
    @State private var exportFileName = "pindou-colors.json"
    @State private var isExporting = false
    @State private var didAttemptInitialSync = false

    private let seedService = DefaultColorSeedService()
    private let backupService = BackupService()

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.97, green: 0.98, blue: 1.0), Color(red: 0.91, green: 0.97, blue: 1.0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        summaryBand
                        searchField
                        seriesChips
                        toolbar
                        groupedContent
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 28)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $editingColor) { color in
                ColorEditorView(color: color)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $isCreatingColor) {
                ColorEditorView(color: nil)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $isImporting) {
                ImportSheetView(existingColors: colors) { result in
                    alertMessage = "导入完成：新增 \(result.inserted)，更新 \(result.updated)"
                }
            }
            .fileExporter(
                isPresented: $isExporting,
                document: exportDocument,
                contentType: exportFileName.hasSuffix(".csv") ? .commaSeparatedText : .json,
                defaultFilename: exportFileName
            ) { result in
                if case .failure(let error) = result {
                    alertMessage = error.localizedDescription
                }
            }
            .alert("提示", isPresented: Binding(get: { alertMessage != nil }, set: { _ in alertMessage = nil })) {
                Button("好", role: .cancel) {}
            } message: {
                Text(alertMessage ?? "")
            }
            .task {
                await seedDefaultColorsIfNeeded()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text("我的豆仓")
                    .font(.system(size: 30, weight: .black))
                Text("颜色、库存和导入备份")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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

    private var summaryBand: some View {
        HStack(spacing: 12) {
            Text("总库存")
                .font(.headline)
            Text("\(totalStock.formatted()) 粒 · \(filteredColors.count) 色号")
                .font(.headline)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(.white)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(.black.opacity(0.08)))
            Spacer()
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.title3)
                .foregroundStyle(.secondary)
            TextField("搜索色号", text: $searchText)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
        }
        .padding(16)
        .background(.white.opacity(0.88))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.black.opacity(0.06)))
    }

    private var seriesChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                chip("slider.horizontal.3", "全部", isActive: selectedSeries == "全部") {
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

    private var toolbar: some View {
        HStack(spacing: 12) {
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

            Button {
                Task { await seedMissingDefaultColors(showAlert: true) }
            } label: {
                Label(isSyncing ? "准备中" : "补齐 291 色", systemImage: "square.grid.3x3")
            }
            .buttonStyle(PillButtonStyle(active: false))
            .disabled(isSyncing)

            Spacer()

            Menu {
                Button("粘贴 HTML 导入") { isImporting = true }
                Button("导出 JSON") { exportJSON() }
                Button("导出 CSV") { exportCSV() }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)

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

    private var groupedContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(groupedSeries, id: \.series) { group in
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("\(group.series) 系列")
                            .font(.title2.bold())
                        Spacer()
                        Text("\(group.items.count) 色号 · \(group.items.reduce(0) { $0 + $1.stockCount }.formatted()) 粒")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if showsGrid {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
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
                ContentUnavailableView("暂无颜色", systemImage: "paintpalette", description: Text("默认 291 色会自动准备，也可以手动新增。"))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
            }
        }
    }

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
            .background(isActive ? Color.indigo : Color.white)
            .foregroundStyle(isActive ? .white : .primary)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(.black.opacity(0.07)))
        }
        .buttonStyle(.plain)
    }

    private var series: [String] {
        Array(Set(colors.map(\.series))).sorted()
    }

    private var filteredColors: [BeadColor] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var result = colors.filter { color in
            let matchesSeries = selectedSeries == "全部" || color.series == selectedSeries
            let matchesSearch = query.isEmpty ||
                color.code.lowercased().contains(query) ||
                color.hex.lowercased().contains(query) ||
                color.displayName.lowercased().contains(query) ||
                color.alias.lowercased().contains(query)
            return matchesSeries && matchesSearch
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

    private var groupedSeries: [(series: String, items: [BeadColor])] {
        Dictionary(grouping: filteredColors, by: \.series)
            .map { ($0.key, $0.value) }
            .sorted { $0.0 < $1.0 }
    }

    private var totalStock: Int {
        colors.reduce(0) { $0 + $1.stockCount }
    }

    @MainActor
    private func seedMissingDefaultColors(showAlert: Bool) async {
        isSyncing = true
        defer { isSyncing = false }

        do {
            let result = try seedService.insertMissingDefaults(into: modelContext, existingColors: colors)
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

    private func exportJSON() {
        do {
            exportDocument = ExportDocument(data: try backupService.exportJSON(colors: colors))
            exportFileName = "pindou-colors.json"
            isExporting = true
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    private func exportCSV() {
        exportDocument = ExportDocument(data: backupService.exportCSV(colors: colors))
        exportFileName = "pindou-colors.csv"
        isExporting = true
    }
}

struct PillButtonStyle: ButtonStyle {
    var active: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(active ? Color.indigo : Color.white)
            .foregroundStyle(active ? .white : .primary)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(.black.opacity(0.07)))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}
