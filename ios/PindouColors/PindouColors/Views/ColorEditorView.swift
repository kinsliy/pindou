import SwiftData
import SwiftUI

struct ColorEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let color: BeadColor?

    @State private var code: String
    @State private var series: String
    @State private var hex: String
    @State private var displayName: String
    @State private var alias: String
    @State private var stockCount: Int
    @State private var note: String
    @State private var enabled: Bool

    init(color: BeadColor?) {
        self.color = color
        _code = State(initialValue: color?.code ?? "")
        _series = State(initialValue: color?.series ?? "")
        _hex = State(initialValue: color?.hex ?? "#FFFFFF")
        _displayName = State(initialValue: color?.displayName ?? "")
        _alias = State(initialValue: color?.alias ?? "")
        _stockCount = State(initialValue: color?.stockCount ?? 1000)
        _note = State(initialValue: color?.note ?? "")
        _enabled = State(initialValue: color?.enabled ?? true)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: hex) ?? .gray)
                        .frame(height: 96)
                        .overlay(alignment: .bottomLeading) {
                            Text(hex.uppercased())
                                .font(.title2.bold())
                                .padding()
                                .foregroundStyle(.black.opacity(0.75))
                        }
                }

                Section("基础信息") {
                    TextField("色号，例如 A1", text: $code)
                        .textInputAutocapitalization(.characters)
                    TextField("系列，例如 A", text: $series)
                        .textInputAutocapitalization(.characters)
                    TextField("HEX，例如 #FAF4C8", text: $hex)
                        .textInputAutocapitalization(.characters)
                    TextField("名称", text: $displayName)
                    TextField("别名", text: $alias)
                }

                Section("库存") {
                    Stepper(value: $stockCount, in: 0...999_999, step: 10) {
                        Text("\(stockCount.formatted()) 粒")
                    }
                    Toggle("启用", isOn: $enabled)
                }

                Section("备注") {
                    TextEditor(text: $note)
                        .frame(minHeight: 120)
                }
            }
            .navigationTitle(color == nil ? "新增颜色" : "编辑颜色")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(code.trimmingCharacters(in: .whitespaces).isEmpty || series.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                if color != nil {
                    ToolbarItem(placement: .bottomBar) {
                        Button("删除", role: .destructive) { delete() }
                    }
                }
            }
        }
    }

    private func save() {
        let now = Date()
        if let color {
            color.code = code.uppercased()
            color.series = series.uppercased()
            color.hex = hex.uppercased()
            color.displayName = displayName.isEmpty ? code.uppercased() : displayName
            color.alias = alias
            color.stockCount = stockCount
            color.note = note
            color.enabled = enabled
            color.updatedAt = now
        } else {
            let newColor = BeadColor(
                code: code.uppercased(),
                series: series.uppercased(),
                hex: hex.uppercased(),
                displayName: displayName.isEmpty ? code.uppercased() : displayName,
                alias: alias,
                enabled: enabled,
                note: note,
                stockCount: stockCount,
                createdAt: now,
                updatedAt: now
            )
            modelContext.insert(newColor)
        }

        try? modelContext.save()
        dismiss()
    }

    private func delete() {
        if let color {
            modelContext.delete(color)
            try? modelContext.save()
        }
        dismiss()
    }
}
