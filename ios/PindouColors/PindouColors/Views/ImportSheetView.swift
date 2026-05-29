import SwiftData
import SwiftUI

struct ImportSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let existingColors: [BeadColor]
    let onComplete: (ImportResult) -> Void

    @State private var html = ""
    @State private var errorMessage: String?

    private let importService = ColorImportService()

    var body: some View {
        NavigationStack {
            Form {
                Section("HTML 内容") {
                    TextEditor(text: $html)
                        .frame(minHeight: 260)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("离线导入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("导入") { importHTML() }
                        .disabled(html.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func importHTML() {
        do {
            let imports = try importService.parse(html: html, sourceURL: "manual-html")
            let result = try importService.upsert(imports, into: modelContext, existingColors: existingColors)
            onComplete(result)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
