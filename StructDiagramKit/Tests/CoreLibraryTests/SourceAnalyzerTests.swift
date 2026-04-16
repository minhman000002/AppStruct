import XCTest
import Foundation
@testable import CoreLibrary

final class SourceAnalyzerTests: XCTestCase {

    /// Helper: write Swift source to a temporary file and return its directory path.
    private func writeTempSwift(_ source: String) throws -> String {
        let dir = NSTemporaryDirectory() + "StructDiagramTests_\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let filePath = dir + "/Test.swift"
        try source.write(toFile: filePath, atomically: true, encoding: .utf8)
        return dir
    }

    func testDetectsStruct() throws {
        let source = """
        struct User {
            var name: String
            var age: Int
        }
        """
        let dir = try writeTempSwift(source)
        let config = AnalysisConfiguration(inputPaths: [dir])
        let result = try SourceAnalyzer(configuration: config).analyze()

        XCTAssertEqual(result.entities.count, 1)
        let entity = result.entities[0]
        XCTAssertEqual(entity.name, "User")
        XCTAssertEqual(entity.kind, .structType)
        XCTAssertEqual(entity.properties.count, 2)
        XCTAssertEqual(entity.properties[0].name, "name")
        XCTAssertEqual(entity.properties[0].typeName, "String")
        XCTAssertEqual(entity.properties[1].name, "age")
        XCTAssertEqual(entity.properties[1].typeName, "Int")
    }

    func testDetectsClassInheritance() throws {
        let source = """
        class Animal {
            var name: String = ""
        }
        class Dog: Animal {
            var breed: String = ""
        }
        """
        let dir = try writeTempSwift(source)
        let config = AnalysisConfiguration(inputPaths: [dir])
        let result = try SourceAnalyzer(configuration: config).analyze()

        XCTAssertEqual(result.entities.count, 2)
        let dog = result.entities.first { $0.name == "Dog" }
        XCTAssertNotNil(dog)
        XCTAssertEqual(dog?.kind, .classType)
        XCTAssertTrue(dog?.inheritedTypes.contains("Animal") ?? false)

        let inheritance = result.relationships.first { $0.kind == .inheritance }
        XCTAssertNotNil(inheritance)
        XCTAssertEqual(inheritance?.sourceName, "Dog")
        XCTAssertEqual(inheritance?.targetName, "Animal")
    }

    func testDetectsProtocolConformance() throws {
        let source = """
        protocol Drawable {
            func draw()
        }
        struct Circle: Drawable {
            func draw() {}
        }
        """
        let dir = try writeTempSwift(source)
        let config = AnalysisConfiguration(inputPaths: [dir])
        let result = try SourceAnalyzer(configuration: config).analyze()

        XCTAssertEqual(result.entities.count, 2)

        let conformance = result.relationships.first { $0.kind == .conformance }
        XCTAssertNotNil(conformance)
        XCTAssertEqual(conformance?.sourceName, "Circle")
        XCTAssertEqual(conformance?.targetName, "Drawable")
    }

    func testDetectsEnum() throws {
        let source = """
        enum Direction {
            case north, south, east, west
            func opposite() -> Direction { .north }
        }
        """
        let dir = try writeTempSwift(source)
        let config = AnalysisConfiguration(inputPaths: [dir])
        let result = try SourceAnalyzer(configuration: config).analyze()

        XCTAssertEqual(result.entities.count, 1)
        let entity = result.entities[0]
        XCTAssertEqual(entity.name, "Direction")
        XCTAssertEqual(entity.kind, .enumType)
        XCTAssertEqual(entity.methods.count, 1)
        XCTAssertEqual(entity.methods[0].name, "opposite")
    }

    func testDetectsMethodSignatures() throws {
        let source = """
        class Calculator {
            func add(a: Int, b: Int) -> Int { a + b }
            static func multiply(_ x: Double, by y: Double) -> Double { x * y }
        }
        """
        let dir = try writeTempSwift(source)
        let config = AnalysisConfiguration(inputPaths: [dir])
        let result = try SourceAnalyzer(configuration: config).analyze()

        let calc = result.entities.first { $0.name == "Calculator" }!
        XCTAssertEqual(calc.methods.count, 2)

        let add = calc.methods.first { $0.name == "add" }!
        XCTAssertEqual(add.parameters.count, 2)
        XCTAssertEqual(add.returnType, "Int")
        XCTAssertFalse(add.isStatic)

        let multiply = calc.methods.first { $0.name == "multiply" }!
        XCTAssertTrue(multiply.isStatic)
        XCTAssertEqual(multiply.parameters.count, 2)
        XCTAssertEqual(multiply.returnType, "Double")
    }

    func testFiltersAccessLevel() throws {
        let source = """
        public class PublicType {}
        internal class InternalType {}
        private class PrivateType {}
        """
        let dir = try writeTempSwift(source)
        let config = AnalysisConfiguration(inputPaths: [dir], minimumAccessLevel: .public)
        let result = try SourceAnalyzer(configuration: config).analyze()

        let names = result.entities.map(\.name)
        XCTAssertTrue(names.contains("PublicType"))
        XCTAssertFalse(names.contains("InternalType"))
        XCTAssertFalse(names.contains("PrivateType"))
    }

    func testExcludesCommonProtocols() throws {
        let source = """
        struct Item: Codable, Hashable, Identifiable {
            let id: String
        }
        """
        let dir = try writeTempSwift(source)
        let config = AnalysisConfiguration(inputPaths: [dir])
        let result = try SourceAnalyzer(configuration: config).analyze()

        let conformances = result.relationships.filter { $0.kind == .conformance }
        XCTAssertTrue(conformances.isEmpty)
    }
}
