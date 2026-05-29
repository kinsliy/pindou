import SwiftData
import XCTest
@testable import PindouColors

final class ColorImportServiceTests: XCTestCase {
    func testParsesPindouHTML() throws {
        let html = """
        <section>
          <h2>## A</h2>
          <p>26 Colors</p>
          <div>A1</div>
          <div>#FAF4C8</div>
          <div>点击复制</div>
          <div>Mard_A1</div>
          <div>A2</div>
          <div>#FFFFD5</div>
          <div>点击复制</div>
          <div>Mard_A2</div>
        </section>
        """

        let service = ColorImportService()
        let colors = try service.parse(html: html, sourceURL: "test")

        XCTAssertEqual(colors.count, 2)
        XCTAssertEqual(colors[0].code, "A1")
        XCTAssertEqual(colors[0].series, "A")
        XCTAssertEqual(colors[0].hex, "#FAF4C8")
        XCTAssertEqual(colors[1].sourceKey, "Mard_A2")
    }

    func testParsesCurrentPindouHTMLFormat() throws {
        let html = """
        <section>
          <h2>A</h2>
          <p>26 Colors</p>
          <div>A1</div>
          <div>#FAF4C8</div>
          <div>点击复制</div>
          <div>Mard_A1</div>
          <div>A10</div>
          <div>#F77C31</div>
          <div>点击复制</div>
          <div>Mard_A10</div>
        </section>
        """

        let colors = try ColorImportService().parse(html: html, sourceURL: "test")

        XCTAssertEqual(colors.count, 2)
        XCTAssertEqual(colors[0].series, "A")
        XCTAssertEqual(colors[0].sourceKey, "Mard_A1")
        XCTAssertEqual(colors[1].code, "A10")
        XCTAssertEqual(colors[1].sourceKey, "Mard_A10")
    }

    @MainActor
    func testUpsertDeduplicatesBySourceKey() throws {
        let schema = Schema([BeadColor.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let service = ColorImportService()
        let imports = [
            ImportedBeadColor(
                code: "A1",
                series: "A",
                hex: "#FAF4C8",
                displayName: "A1",
                alias: "",
                sortOrder: 1,
                enabled: true,
                sourceURL: "test",
                sourceKey: "Mard_A1",
                note: "",
                stockCount: 1000
            )
        ]

        let first = try service.upsert(imports, into: context, existingColors: [])
        let descriptor = FetchDescriptor<BeadColor>()
        let existing = try context.fetch(descriptor)
        let second = try service.upsert(imports, into: context, existingColors: existing)

        XCTAssertEqual(first.inserted, 1)
        XCTAssertEqual(second.inserted, 0)
        XCTAssertEqual(second.updated, 1)
        XCTAssertEqual(try context.fetch(descriptor).count, 1)
    }

    @MainActor
    func testUpsertDeduplicatesBySeriesAndCode() throws {
        let schema = Schema([BeadColor.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let existingColor = BeadColor(code: "A1", series: "A", hex: "#FFFFFF")
        context.insert(existingColor)

        let imports = [
            ImportedBeadColor(
                code: "A1",
                series: "A",
                hex: "#FAF4C8",
                displayName: "A1",
                alias: "",
                sortOrder: 1,
                enabled: true,
                sourceURL: "test",
                sourceKey: "Mard_A1",
                note: "",
                stockCount: 1000
            )
        ]

        let descriptor = FetchDescriptor<BeadColor>()
        let existing = try context.fetch(descriptor)
        let result = try ColorImportService().upsert(imports, into: context, existingColors: existing)
        let saved = try context.fetch(descriptor)

        XCTAssertEqual(result.inserted, 0)
        XCTAssertEqual(result.updated, 1)
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(saved[0].hex, "#FAF4C8")
        XCTAssertEqual(saved[0].sourceKey, "Mard_A1")
    }

    func testBackupExportsCSV() {
        let color = BeadColor(code: "A1", series: "A", hex: "#FAF4C8", sourceKey: "Mard_A1")
        let data = BackupService().exportCSV(colors: [color])
        let csv = String(data: data, encoding: .utf8)

        XCTAssertTrue(csv?.contains("code,series,hex") == true)
        XCTAssertTrue(csv?.contains("A1,A,#FAF4C8") == true)
    }
}
