import XCTest
import Foundation
@testable import CoreLibrary

final class ReadmeUpdaterTests: XCTestCase {

    private let updater = ReadmeUpdater()

    func testReplacesExistingBlock() {
        let existing = """
        # My Project

        Some intro text.

        <!-- DIAGRAM-START -->
        Old diagram content here.
        <!-- DIAGRAM-END -->

        ## Footer
        """

        let diagram = "classDiagram\n    class Foo"
        let result = updater.replaceDiagramBlock(in: existing, with: diagram)

        XCTAssertTrue(result.contains("```mermaid"))
        XCTAssertTrue(result.contains("classDiagram"))
        XCTAssertTrue(result.contains("class Foo"))
        XCTAssertFalse(result.contains("Old diagram content here."))
        XCTAssertTrue(result.contains("## Footer"))
        XCTAssertTrue(result.contains("<!-- DIAGRAM-START -->"))
        XCTAssertTrue(result.contains("<!-- DIAGRAM-END -->"))
    }

    func testAppendsWhenNoMarkers() {
        let existing = """
        # My Project

        Some content.
        """

        let diagram = "classDiagram\n    class Bar"
        let result = updater.replaceDiagramBlock(in: existing, with: diagram)

        XCTAssertTrue(result.hasPrefix("# My Project"))
        XCTAssertTrue(result.contains("```mermaid"))
        XCTAssertTrue(result.contains("classDiagram"))
        XCTAssertTrue(result.contains("class Bar"))
        XCTAssertTrue(result.contains("<!-- DIAGRAM-START -->"))
        XCTAssertTrue(result.contains("<!-- DIAGRAM-END -->"))
    }

    func testCreatesNewReadme() throws {
        let tempDir = NSTemporaryDirectory() + "ReadmeTest_\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        let readmePath = tempDir + "/README.md"

        let diagram = "classDiagram\n    class NewEntity"
        try updater.update(readmePath: readmePath, mermaidDiagram: diagram, projectName: "TestProject")

        let content = try String(contentsOfFile: readmePath, encoding: .utf8)
        XCTAssertTrue(content.contains("# TestProject"))
        XCTAssertTrue(content.contains("```mermaid"))
        XCTAssertTrue(content.contains("classDiagram"))
        XCTAssertTrue(content.contains("class NewEntity"))

        try FileManager.default.removeItem(atPath: tempDir)
    }

    func testPreservesOutsideContent() {
        let existing = """
        # Header

        Important text before.

        <!-- DIAGRAM-START -->
        old stuff
        <!-- DIAGRAM-END -->

        Important text after.
        """

        let result = updater.replaceDiagramBlock(in: existing, with: "classDiagram")

        XCTAssertTrue(result.contains("Important text before."))
        XCTAssertTrue(result.contains("Important text after."))
        XCTAssertFalse(result.contains("old stuff"))
    }
}
