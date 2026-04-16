import XCTest
import Foundation
@testable import CoreLibrary

final class MermaidGeneratorTests: XCTestCase {

    func testGeneratesHeader() {
        let result = AnalysisResult(entities: [], relationships: [])
        let generator = MermaidGenerator()
        let output = generator.generate(from: result)
        XCTAssertTrue(output.hasPrefix("classDiagram"))
    }

    func testRendersStructAnnotation() {
        let entity = Entity(
            name: "User",
            kind: .structType,
            properties: [
                Property(name: "name", typeName: "String"),
                Property(name: "age", typeName: "Int"),
            ]
        )
        let result = AnalysisResult(entities: [entity], relationships: [])
        let generator = MermaidGenerator()
        let output = generator.generate(from: result)

        XCTAssertTrue(output.contains("class User"))
        XCTAssertTrue(output.contains("<<Struct>>"))
        XCTAssertTrue(output.contains("~name: String"))
        XCTAssertTrue(output.contains("~age: Int"))
    }

    func testRendersProtocolAnnotation() {
        let entity = Entity(
            name: "Drawable",
            kind: .protocolType,
            methods: [
                Method(name: "draw", parameters: [], returnType: nil),
            ]
        )
        let result = AnalysisResult(entities: [entity], relationships: [])
        let generator = MermaidGenerator()
        let output = generator.generate(from: result)

        XCTAssertTrue(output.contains("<<Interface>>"))
        XCTAssertTrue(output.contains("~draw()"))
    }

    func testRendersInheritance() {
        let entities = [
            Entity(name: "Animal", kind: .classType),
            Entity(name: "Dog", kind: .classType, inheritedTypes: ["Animal"]),
        ]
        let relationships = [
            Relationship(kind: .inheritance, sourceName: "Dog", targetName: "Animal"),
        ]
        let result = AnalysisResult(entities: entities, relationships: relationships)
        let generator = MermaidGenerator()
        let output = generator.generate(from: result)

        XCTAssertTrue(output.contains("Animal <|-- Dog"))
    }

    func testRendersConformance() {
        let entities = [
            Entity(name: "Drawable", kind: .protocolType),
            Entity(name: "Circle", kind: .structType, inheritedTypes: ["Drawable"]),
        ]
        let relationships = [
            Relationship(kind: .conformance, sourceName: "Circle", targetName: "Drawable"),
        ]
        let result = AnalysisResult(entities: entities, relationships: relationships)
        let generator = MermaidGenerator()
        let output = generator.generate(from: result)

        XCTAssertTrue(output.contains("Drawable <|.. Circle"))
    }

    func testRendersAccessPrefixes() {
        let entity = Entity(
            name: "Example",
            kind: .classType,
            properties: [
                Property(name: "publicProp", typeName: "String", access: .public),
                Property(name: "privateProp", typeName: "Int", access: .private),
                Property(name: "internalProp", typeName: "Bool", access: .internal),
            ]
        )
        let result = AnalysisResult(entities: [entity], relationships: [])
        let generator = MermaidGenerator()
        let output = generator.generate(from: result)

        XCTAssertTrue(output.contains("+publicProp: String"))
        XCTAssertTrue(output.contains("-privateProp: Int"))
        XCTAssertTrue(output.contains("~internalProp: Bool"))
    }

    func testHidesProperties() {
        let entity = Entity(
            name: "Foo",
            kind: .structType,
            properties: [Property(name: "bar", typeName: "String")]
        )
        let result = AnalysisResult(entities: [entity], relationships: [])
        let config = MermaidConfiguration(showProperties: false)
        let generator = MermaidGenerator(configuration: config)
        let output = generator.generate(from: result)

        XCTAssertFalse(output.contains("bar"))
    }

    func testHidesMethods() {
        let entity = Entity(
            name: "Foo",
            kind: .classType,
            methods: [Method(name: "doSomething", parameters: [], returnType: nil)]
        )
        let result = AnalysisResult(entities: [entity], relationships: [])
        let config = MermaidConfiguration(showMethods: false)
        let generator = MermaidGenerator(configuration: config)
        let output = generator.generate(from: result)

        XCTAssertFalse(output.contains("doSomething"))
    }

    func testAssociationFilteredByKnownEntities() {
        let entities = [
            Entity(name: "ViewModel", kind: .classType),
            Entity(name: "Service", kind: .classType),
        ]
        let relationships = [
            Relationship(kind: .association, sourceName: "ViewModel", targetName: "Service"),
            Relationship(kind: .association, sourceName: "ViewModel", targetName: "UnknownType"),
        ]
        let result = AnalysisResult(entities: entities, relationships: relationships)
        let generator = MermaidGenerator()
        let output = generator.generate(from: result)

        XCTAssertTrue(output.contains("ViewModel --> Service"))
        XCTAssertFalse(output.contains("UnknownType"))
    }

    func testRendersStaticMembers() {
        let entity = Entity(
            name: "Config",
            kind: .classType,
            properties: [
                Property(name: "shared", typeName: "Config", access: .public, isStatic: true),
            ],
            methods: [
                Method(name: "reset", parameters: [], returnType: nil, access: .public, isStatic: true),
            ]
        )
        let result = AnalysisResult(entities: [entity], relationships: [])
        let generator = MermaidGenerator()
        let output = generator.generate(from: result)

        XCTAssertTrue(output.contains("+$ shared: Config"))
        XCTAssertTrue(output.contains("+$ reset()"))
    }
}
