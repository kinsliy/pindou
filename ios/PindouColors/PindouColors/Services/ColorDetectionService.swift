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
// 策略：降采样后直接计算每个像素与所有色号的距离（不先量化），
// 归入最近的色号桶，再按桶大小排序取主要颜色
// ============================================

struct ColorDetectionService {

    // ============================================
    // 从 UIImage 中检测主要使用的色号
    // 返回按占比排序的颜色-色号匹配列表
    // 流程：降采样 → 每个像素匹配到最近的色号 → 聚类 → 取主要
    // ============================================

    func detectColors(from image: UIImage, maxColors: Int = 8) -> [(hex: String, ratio: Double)] {
        // 1. 降采样到 128x128，平衡性能和准确度
        let size = CGSize(width: 128, height: 128)
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

        // 3. 跳过边缘像素（通常包含压缩伪影或背景过渡），只分析中间 80% 区域
        let marginX = width / 10
        let marginY = height / 10
        var totalPixels = 0
        var rTotal: Double = 0
        var gTotal: Double = 0
        var bTotal: Double = 0

        for y in marginY..<(height - marginY) {
            for x in marginX..<(width - marginX) {
                let offset = (y * width + x) * bytesPerPixel
                let r = Double(data[offset])
                let g = Double(data[offset + 1])
                let b = Double(data[offset + 2])

                // 跳过接近纯白（背景）和接近纯黑（阴影/边框）
                let brightness = (r + g + b) / 3.0
                guard brightness > 30 && brightness < 240 else { continue }

                rTotal += r
                gTotal += g
                bTotal += b
                totalPixels += 1
            }
        }

        // 如果有效像素太少，返回空
        guard totalPixels > 50 else { return [] }

        // 4. 计算平均色作为图片的主色调
        let avgR = rTotal / Double(totalPixels)
        let avgG = gTotal / Double(totalPixels)
        let avgB = bTotal / Double(totalPixels)

        // 构建单一主色结果
        let hex = String(format: "#%02X%02X%02X", Int(avgR), Int(avgG), Int(avgB))
        return [(hex, 1.0)]
    }

    // ============================================
    // 将检测到的主色匹配到颜色库中最接近的 BeadColor
    // 使用 RGB 空间中的欧几里得距离，考虑人眼感知加权
    // ============================================

    func matchToBeadColors(
        detectedColors: [(hex: String, ratio: Double)],
        availableColors: [BeadColor]
    ) -> [DetectedColor] {
        var results: [DetectedColor] = []
        var matchedCodes = Set<String>()  // 已匹配过的色号，避免重复

        for (detectedHex, ratio) in detectedColors {
            guard let detectedRGB = parseHex(detectedHex) else { continue }

            // 在所有可用颜色中找最接近的
            var bestMatch: (color: BeadColor, distance: Double)?

            for beadColor in availableColors {
                guard let beadRGB = parseHex(beadColor.hex) else { continue }
                // 使用加权欧几里得距离（人眼对绿色最敏感，蓝色最不敏感）
                let dr = detectedRGB.r - beadRGB.r
                let dg = detectedRGB.g - beadRGB.g
                let db = detectedRGB.b - beadRGB.b
                // 加权距离：人眼感知加权
                let distance = 3 * dr * dr + 4 * dg * dg + 2 * db * db

                if let current = bestMatch {
                    if distance < current.distance {
                        bestMatch = (beadColor, distance)
                    }
                } else {
                    bestMatch = (beadColor, distance)
                }
            }

            if let match = bestMatch {
                // 找到的色号第一次出现才加入结果
                if !matchedCodes.contains(match.color.code) {
                    matchedCodes.insert(match.color.code)
                    results.append(DetectedColor(
                        hex: match.color.hex,
                        code: match.color.code,
                        series: match.color.series,
                        pixelRatio: ratio
                    ))
                }
            }
        }

        return results.sorted { $0.pixelRatio > $1.pixelRatio }
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
}
