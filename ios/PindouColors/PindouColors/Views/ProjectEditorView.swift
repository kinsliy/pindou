import SwiftData
import SwiftUI
import PhotosUI

// ============================================
// ProjectEditorMode - 编辑器模式
// ============================================

enum ProjectEditorMode {
    case create   // 新建图纸
    case edit     // 编辑已有图纸
}

// ============================================
// ProjectEditorView - 图纸编辑器
// 支持上传图片、自动识别颜色、手动调整用量
// 样式参考 iOS Settings 列表风格，简洁专业
// ============================================

struct ProjectEditorView: View {
    // ============================================
    // SwiftData 依赖注入
    // ============================================
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // 获取所有颜色用于匹配
    @Query(sort: [SortDescriptor(\BeadColor.series), SortDescriptor(\BeadColor.sortOrder)])
    private var allColors: [BeadColor]

    // ============================================
    // Props
    // ============================================

    let mode: ProjectEditorMode
    var existingProject: Project?

    // ============================================
    // 状态变量
    // ============================================

    @State private var name: String = ""
    @State private var note: String = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var thumbnailData: Data?
    @State private var isAnalyzing = false
    @State private var detectedUsages: [DetectedUsage] = []
    @State private var alertMessage: String?
    @State private var showColorPicker = false   // 手动添加颜色时弹窗

    // ============================================
    // 检测到的颜色用量
    // ============================================

    struct DetectedUsage: Identifiable {
        let id = UUID()
        var beadColor: BeadColor?
        var count: String
        var isAutoDetected: Bool
    }

    private let detectionService = ColorDetectionService()

    // ============================================
    // View 主体 — 使用 List 风格
    // ============================================

    var body: some View {
        NavigationStack {
            List {
                // Section 1: 图纸图片
                Section {
                    imageRow
                } header: {
                    Text("图纸图片")
                }

                // Section 2: 基本信息
                Section {
                    // 图纸名称
                    HStack {
                        Text("名称")
                            .foregroundStyle(.primary)
                        TextField("必填", text: $name)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.secondary)
                    }

                    // 备注
                    ZStack(alignment: .topLeading) {
                        if note.isEmpty {
                            Text("备注（可选）")
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                        }
                        TextEditor(text: $note)
                            .frame(minHeight: 60)
                            .scrollContentBackground(.hidden)
                    }
                } header: {
                    Text("基本信息")
                }

                // Section 3: 颜色用量
                Section {
                    if detectedUsages.isEmpty {
                        // 空状态提示
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                Image(systemName: "paintpalette")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                                Text("选择图片后自动识别，或手动添加")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 12)
                            Spacer()
                        }
                    } else {
                        // 颜色用量列表
                        ForEach(Array(detectedUsages.enumerated()), id: \.element.id) { index, usage in
                            usageRow(usage: usage, index: index)
                        }
                        .onDelete { indexSet in
                            detectedUsages.remove(atOffsets: indexSet)
                        }
                    }

                    // 手动添加颜色
                    Button {
                        showColorPicker = true
                    } label: {
                        Label("添加颜色", systemImage: "plus.circle")
                            .font(.subheadline)
                    }
                    // 颜色选择弹窗
                    .confirmationDialog("选择要添加的颜色", isPresented: $showColorPicker) {
                        // 按系列分组显示
                        let seriesList = Array(Set(allColors.map(\.series))).sorted()
                        ForEach(seriesList, id: \.self) { series in
                            Button("\(series) 系列") {
                                addColorFromSeries(series)
                            }
                        }
                        Button("取消", role: .cancel) {}
                    } message: {
                        Text("选择一个系列来添加颜色")
                    }

                } header: {
                    HStack {
                        Text("颜色用量")
                        if !detectedUsages.isEmpty {
                            Spacer()
                            Text("\(detectedUsages.count) 色")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(mode == .create ? "新建图纸" : "编辑图纸")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { saveProject() }
                        .disabled(name.isEmpty || detectedUsages.isEmpty)
                }
            }
            .alert("提示", isPresented: Binding(
                get: { alertMessage != nil },
                set: { _ in alertMessage = nil }
            )) {
                Button("好", role: .cancel) {}
            } message: {
                Text(alertMessage ?? "")
            }
            .onAppear {
                if let project = existingProject {
                    name = project.name
                    note = project.note
                    selectedImageData = project.imageData
                    thumbnailData = project.thumbnailData
                    detectedUsages = project.colorUsages.map {
                        DetectedUsage(beadColor: $0.color, count: "\($0.count)", isAutoDetected: false)
                    }
                }
            }
        }
    }

    // ============================================
    // 子视图
    // ============================================

    // 图片选择行
    private var imageRow: some View {
        HStack(spacing: 14) {
            // 缩略图区域：始终显示当前图片或占位符
            if let imageData = selectedImageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.black.opacity(0.12)))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.06))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: "photo.badge.plus")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    )
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.black.opacity(0.12)))
            }

            VStack(alignment: .leading, spacing: 6) {
                // 选择/更换图片按钮 — 始终可见
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label(selectedImageData == nil ? "选择图片" : "更换图片",
                          systemImage: selectedImageData == nil ? "photo.on.rectangle" : "arrow.triangle.2.circlepath")
                        .font(.subheadline.weight(.medium))
                }

                if selectedImageData != nil {
                    // 已选图片时显示识别和清除按钮
                    Button {
                        analyzeColors()
                    } label: {
                        HStack(spacing: 4) {
                            if isAnalyzing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Label(isAnalyzing ? "识别中..." : "重新识别颜色",
                                  systemImage: isAnalyzing ? "" : "wand.and.stars")
                                .font(.subheadline)
                        }
                    }
                    .disabled(isAnalyzing)

                    Button(role: .destructive) {
                        selectedImageData = nil
                        thumbnailData = nil
                        detectedUsages = []
                    } label: {
                        Label("清除图片", systemImage: "trash")
                            .font(.subheadline)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        // 监听图片选择：每次选择新图片时处理
        // 注意：PhotosPicker 选择后会自动重置 selectedPhotoItem，
        // 再次选择同一张图时不会触发 onChange，所以不会"删掉"图片
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                guard let data = try? await newItem.loadTransferable(type: Data.self) else { return }
                selectedImageData = data
                if let uiImage = UIImage(data: data) {
                    thumbnailData = await generateThumbnail(uiImage)
                    await autoDetectColors(from: uiImage)
                }
            }
        }
    }

    // 颜色用量行
    private func usageRow(usage: DetectedUsage, index: Int) -> some View {
        HStack(spacing: 12) {
            // 色块 + 色号信息
            if let color = usage.beadColor {
                RoundedRectangle(cornerRadius: 6)
                    .fill(color.color)
                    .frame(width: 32, height: 32)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(.black.opacity(0.12)))

                VStack(alignment: .leading, spacing: 1) {
                    Text(color.code)
                        .font(.subheadline.weight(.medium))
                    Text(color.series)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                // 未选颜色时
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black.opacity(0.06))
                    .frame(width: 32, height: 32)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(.black.opacity(0.12)))
                    .overlay(Image(systemName: "questionmark").font(.caption2).foregroundStyle(.secondary))

                Text("选择颜色")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // 用量输入
            HStack(spacing: 4) {
                TextField("0", text: $detectedUsages[index].count)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 50)
                Text("粒")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // 自动识别标记
            if usage.isAutoDetected {
                Image(systemName: "wand.and.stars")
                    .font(.caption2)
                    .foregroundStyle(.indigo)
            }
        }
        .padding(.vertical, 2)
    }

    // ============================================
    // 方法
    // ============================================

    // 从系列添加颜色
    private func addColorFromSeries(_ series: String) {
        let colorsInSeries = allColors.filter { $0.series == series }.sorted { $0.code < $1.code }
        guard let firstColor = colorsInSeries.first else { return }

        detectedUsages.append(DetectedUsage(
            beadColor: firstColor,
            count: "0",
            isAutoDetected: false
        ))
    }

    // 生成缩略图
    private func generateThumbnail(_ image: UIImage) async -> Data? {
        let size = CGSize(width: Project.thumbnailSize, height: Project.thumbnailSize * image.size.height / image.size.width)
        UIGraphicsBeginImageContextWithOptions(size, true, 1)
        image.draw(in: CGRect(origin: .zero, size: size))
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result?.jpegData(compressionQuality: 0.6)
    }

    // 自动识别颜色
    private func autoDetectColors(from image: UIImage) async {
        isAnalyzing = true
        defer { isAnalyzing = false }

        let detected = detectionService.detectColors(from: image)
        let matched = detectionService.matchToBeadColors(
            detectedColors: detected,
            availableColors: allColors
        )

        detectedUsages = matched.map { detectedColor in
            DetectedUsage(
                beadColor: allColors.first { $0.code == detectedColor.code },
                count: "0",
                isAutoDetected: true
            )
        }
    }

    // 分析颜色
    private func analyzeColors() {
        guard let imageData = selectedImageData,
              let uiImage = UIImage(data: imageData) else { return }

        isAnalyzing = true
        Task {
            let detected = detectionService.detectColors(from: uiImage)
            let matched = detectionService.matchToBeadColors(
                detectedColors: detected,
                availableColors: allColors
            )

            detectedUsages = matched.map { detected in
                DetectedUsage(
                    beadColor: allColors.first { $0.code == detected.code },
                    count: "0",
                    isAutoDetected: true
                )
            }
            isAnalyzing = false
        }
    }

    // 保存图纸
    private func saveProject() {
        var usages: [ProjectColorUsage] = []
        for usage in detectedUsages {
            guard let beadColor = usage.beadColor,
                  let count = Int(usage.count), count > 0 else { continue }
            let colorUsage = ProjectColorUsage(color: beadColor, count: count)
            usages.append(colorUsage)
        }

        guard !usages.isEmpty else {
            alertMessage = "请至少添加一种颜色的用量"
            return
        }

        if mode == .create {
            let project = Project(
                name: name,
                status: .notStarted,
                note: note,
                imageData: selectedImageData,
                thumbnailData: thumbnailData,
                colorUsages: usages
            )
            modelContext.insert(project)
        } else if let project = existingProject {
            project.name = name
            project.note = note
            project.imageData = selectedImageData
            project.thumbnailData = thumbnailData
            project.updatedAt = Date()
            for usage in project.colorUsages {
                modelContext.delete(usage)
            }
            project.colorUsages = usages
        }

        try? modelContext.save()
        dismiss()
    }
}
