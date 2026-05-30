import UIKit
import SwiftData

// ============================================
// DetectedColor - 检测到的颜色信息
// ============================================

struct DetectedColor {
    let hex: String       // 匹配到的色号 HEX
    let code: String      // 匹配到的色号（如 "A1"）
    let series: String    // 系列
    let pixelRatio: Double // 该颜色在图片中的像素占比（0~1）
}

// ============================================
// ColorDetectionService - 图片颜色识别服务
// 从图片中提取主色，并匹配到颜色库中最接近的色号
// ============================================

struct ColorDetectionService {

    // ============================================
    // 从 UIImage 中提取主色
    // 使用颜色量化算法：降采样后聚类相近颜色
    // 返回按占比排序的颜色列表
    // ============================================

    func detectColors(from image: UIImage, maxColors: Int = 10) -> [(hex: String, ratio: Double)] {
        // 1. 降采样到小图以提高性能
        let size = CGSize(width: 64, height: 64)
        UIGraphicsBeginImageContextWithOptions(size, true, 1)
        image.draw(in: CGRect(origin: .zero, size: size))
        guard let smallImage = UIGraphicsGetImageFromCurrentImageContext() else {
            UIGraphicsEndImageContext()
            return []
        }
        UIGraphicsEndImageContext()

        // 2. 读取像素数据
        guard let cgImage = smallImage.cgImage,
              let dataProvider = cgImage.dataProvider,
              let pixelData = dataProvider.data else {
            return []
        }

        let data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
        let width = Int(smallImage.size.width)
        let height = Int(smallImage.size.height)
        let bytesPerPixel = 4

        // 3. 提取所有像素的 RGB 值，忽略接近纯白/纯黑的背景色
        var colorCounts: [String: Int] = [:]
        var totalPixels = 0

        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * bytesPerPixel
                let r = data[offset]
                let g = data[offset + 1]
                let b = data[offset + 2]

                // 忽略接近纯白的像素（背景）
                let isWhite = r > 240 && g > 240 && b > 240
                // 忽略接近纯黑的像素（阴影/边框）
                let isBlack = r < 15 && g < 15 && b < 15
                guard !isWhite, !isBlack else { continue }

                // 颜色量化：将颜色近似到 4 阶（减少颜色数量，聚类相近色）
                let quantizedR = (r / 64) * 64 + 32
                let quantizedG = (g / 64) * 64 + 32
                let quantizedB = (b / 64) * 64 + 32

                let hex = String(format: "#%02X%02X%02X", quantizedR, quantizedG, quantizedB)
                colorCounts[hex, default: 0] += 1
                totalPixels += 1
            }
        }

        guard totalPixels > 0 else { return [] }

        // 4. 按出现频率排序，取前 maxColors 个
        let sorted = colorCounts
            .sorted { $0.value > $1.value }
            .prefix(maxColors)
            .map { ($0.key, Double($0.value) / Double(totalPixels)) }

        return sorted
    }

    // ============================================
    // 将检测到的颜色匹配到颜色库中最接近的 BeadColor
    // 使用 RGB 空间中的欧几里得距离
    // ============================================

    func matchToBeadColors(
        detectedColors: [(hex: String, ratio: Double)],
        availableColors: [BeadColor]
    ) -> [DetectedColor] {
        // 构建颜色缓存（按系列分组）
        let colorMap = Dictionary(grouping: availableColors, by: \.series)

        var results: [DetectedColor] = []

        for (detectedHex, ratio) in detectedColors {
            // 解析检测到的 RGB
            guard let detectedRGB = parseHex(detectedHex) else { continue }

            // 在所有可用颜色中找最接近的
            var bestMatch: (color: BeadColor, distance: Double)?

            for (_, colors) in colorMap {
                for beadColor in colors {
                    guard let beadRGB = parseHex(beadColor.hex) else { continue }
                    let distance = colorDistance(detectedRGB, beadRGB)
                    if let current = bestMatch {
                        if distance < current.distance {
                            bestMatch = (beadColor, distance)
                        }
                    } else {
                        bestMatch = (beadColor, distance)
                    }
                }
            }

            if let match = bestMatch {
                results.append(DetectedColor(
                    hex: match.color.hex,
                    code: match.color.code,
                    series: match.color.series,
                    pixelRatio: ratio
                ))
            }
        }

        // 去重：如果多个检测色匹配到同一个色号，合并占比
        var merged: [String: DetectedColor] = [:]
        for result in results {
            if var existing = merged[result.code] {
                existing = DetectedColor(
                    hex: result.hex,
                    code: result.code,
                    series: result.series,
                    pixelRatio: existing.pixelRatio + result.pixelRatio
                )
                merged[result.code] = existing
            } else {
                merged[result.code] = result
            }
        }

        return merged.values.sorted { $0.pixelRatio > $1.pixelRatio }
    }

    // ============================================
    // 私有辅助方法
    // ============================================

    // 解析 HEX 字符串为 RGB 元组
    private func parseHex(_ hex: String) -> (r: Double, g: Double, b: Double)? {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let number = Int(value, radix: 16) else { return nil }
        return (
            r: Double((number >> 16) & 0xFF),
            g: Double((number >> 8) & 0xFF),
            b: Double(number & 0xFF)
        )
    }

    // 计算两个 RGB 颜色之间的欧几里得距离
    private func colorDistance(_ a: (r: Double, g: Double, b: Double),
                                _ b: (r: Double, g: Double, b: Double)) -> Double {
        let dr = a.r - b.r
        let dg = a.g - b.g
        let db = a.b - b.b
        return dr * dr + dg * dg + db * db
    }
}
