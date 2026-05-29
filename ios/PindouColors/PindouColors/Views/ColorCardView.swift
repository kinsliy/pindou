import SwiftData
import SwiftUI

struct ColorCardView: View {
    @Environment(\.modelContext) private var modelContext
    let color: BeadColor
    var isCompact = false
    var onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 10 : 14) {
            HStack {
                Text(color.code)
                    .font(.title3.bold())
                Text(color.isStockEnough ? "库存充足" : "需要补豆")
                    .font(.caption.bold())
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .foregroundStyle(color.isStockEnough ? .green : .orange)
                    .overlay(Capsule().stroke(color.isStockEnough ? .green.opacity(0.35) : .orange.opacity(0.45)))
                Spacer()
                Button(action: onTap) {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                        .overlay(Circle().stroke(.black.opacity(0.08)))
                }
            }

            HStack(alignment: .lastTextBaseline, spacing: 5) {
                Text(color.stockCount.formatted())
                    .font(.system(size: isCompact ? 34 : 40, weight: .black))
                    .foregroundStyle(readableTextColor)
                Text("粒")
                    .font(.headline)
                    .foregroundStyle(readableTextColor.opacity(0.65))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, isCompact ? 12 : 18)
            .background(color.color)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.black.opacity(0.08), lineWidth: 3))

            if !isCompact {
                HStack(spacing: 12) {
                    Button {
                        updateStock(-10)
                    } label: {
                        Label("减少", systemImage: "minus.circle.fill")
                            .font(.headline)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .tint(.red)

                    Spacer()

                    Button {
                        updateStock(10)
                    } label: {
                        Label("补豆", systemImage: "plus.circle.fill")
                            .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                }
            }
        }
        .padding(14)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.black.opacity(0.08)))
    }

    private func updateStock(_ delta: Int) {
        color.stockCount = max(0, color.stockCount + delta)
        color.updatedAt = Date()
        try? modelContext.save()
    }

    private var readableTextColor: Color {
        guard let rgb = RGB(hex: color.hex) else {
            return .primary
        }
        return rgb.luminance > 0.56 ? .black.opacity(0.85) : .white
    }
}

private struct RGB {
    let red: Double
    let green: Double
    let blue: Double

    init?(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let number = Int(value, radix: 16) else { return nil }
        red = Double((number >> 16) & 0xFF) / 255
        green = Double((number >> 8) & 0xFF) / 255
        blue = Double(number & 0xFF) / 255
    }

    var luminance: Double {
        0.299 * red + 0.587 * green + 0.114 * blue
    }
}
