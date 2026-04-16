import Foundation
import SwiftSyntax

/// A `SyntaxVisitor` that walks a Swift source file's AST and extracts
/// type declarations (class, struct, enum, protocol) along with their
/// members and inheritance relationships.
final class SwiftEntityVisitor: SyntaxVisitor {

    // MARK: - Collected Data

    private(set) var entities: [Entity] = []
    private(set) var relationships: [Relationship] = []

    private let filePath: String?
    private let minimumAccessLevel: AccessLevel

    // MARK: - Init

    init(filePath: String? = nil, minimumAccessLevel: AccessLevel = .internal) {
        self.filePath = filePath
        self.minimumAccessLevel = minimumAccessLevel
        super.init(viewMode: .sourceAccurate)
    }

    // MARK: - Class

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        let access = accessLevel(from: node.modifiers)
        guard access <= minimumAccessLevel else { return .skipChildren }

        let name = node.name.text
        let inherited = inheritedTypeNames(from: node.inheritanceClause)
        let properties = extractProperties(from: node.memberBlock)
        let methods = extractMethods(from: node.memberBlock)

        let entity = Entity(
            name: name,
            kind: .classType,
            access: access,
            properties: properties,
            methods: methods,
            inheritedTypes: inherited,
            filePath: filePath
        )
        entities.append(entity)
        addRelationships(for: name, kind: .classType, inherited: inherited, properties: properties)

        return .visitChildren
    }

    // MARK: - Struct

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        let access = accessLevel(from: node.modifiers)
        guard access <= minimumAccessLevel else { return .skipChildren }

        let name = node.name.text
        let inherited = inheritedTypeNames(from: node.inheritanceClause)
        let properties = extractProperties(from: node.memberBlock)
        let methods = extractMethods(from: node.memberBlock)

        let entity = Entity(
            name: name,
            kind: .structType,
            access: access,
            properties: properties,
            methods: methods,
            inheritedTypes: inherited,
            filePath: filePath
        )
        entities.append(entity)
        addRelationships(for: name, kind: .structType, inherited: inherited, properties: properties)

        return .visitChildren
    }

    // MARK: - Enum

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        let access = accessLevel(from: node.modifiers)
        guard access <= minimumAccessLevel else { return .skipChildren }

        let name = node.name.text
        let inherited = inheritedTypeNames(from: node.inheritanceClause)
        let properties = extractProperties(from: node.memberBlock)
        let methods = extractMethods(from: node.memberBlock)

        let entity = Entity(
            name: name,
            kind: .enumType,
            access: access,
            properties: properties,
            methods: methods,
            inheritedTypes: inherited,
            filePath: filePath
        )
        entities.append(entity)
        addRelationships(for: name, kind: .enumType, inherited: inherited, properties: properties)

        return .visitChildren
    }

    // MARK: - Protocol

    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        let access = accessLevel(from: node.modifiers)
        guard access <= minimumAccessLevel else { return .skipChildren }

        let name = node.name.text
        let inherited = inheritedTypeNames(from: node.inheritanceClause)

        // Protocol members are requirements, not concrete implementations.
        // We extract them similarly for display purposes.
        let properties = extractProperties(from: node.memberBlock)
        let methods = extractMethods(from: node.memberBlock)

        let entity = Entity(
            name: name,
            kind: .protocolType,
            access: access,
            properties: properties,
            methods: methods,
            inheritedTypes: inherited,
            filePath: filePath
        )
        entities.append(entity)

        // Protocol-to-protocol inheritance
        for parentName in inherited {
            relationships.append(
                Relationship(kind: .protocolInheritance, sourceName: name, targetName: parentName)
            )
        }

        return .visitChildren
    }

    // MARK: - Helpers: Access Level

    private func accessLevel(from modifiers: DeclModifierListSyntax) -> AccessLevel {
        for modifier in modifiers {
            switch modifier.name.text {
            case "open": return .open
            case "public": return .public
            case "internal": return .internal
            case "fileprivate": return .fileprivate
            case "private": return .private
            default: continue
            }
        }
        return .internal
    }

    // MARK: - Helpers: Inheritance Clause

    private func inheritedTypeNames(from clause: InheritanceClauseSyntax?) -> [String] {
        guard let clause else { return [] }
        return clause.inheritedTypes.map { $0.type.trimmedDescription }
    }

    // MARK: - Helpers: Properties

    private func extractProperties(from memberBlock: MemberBlockSyntax) -> [Property] {
        var result: [Property] = []
        for member in memberBlock.members {
            guard let varDecl = member.decl.as(VariableDeclSyntax.self) else { continue }
            let access = accessLevel(from: varDecl.modifiers)
            let isStatic = varDecl.modifiers.contains { $0.name.text == "static" || $0.name.text == "class" }

            for binding in varDecl.bindings {
                guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else { continue }
                let name = pattern.identifier.text
                let typeName = binding.typeAnnotation?.type.trimmedDescription
                let isComputed = binding.accessorBlock != nil

                result.append(
                    Property(
                        name: name,
                        typeName: typeName,
                        access: access,
                        isStatic: isStatic,
                        isComputed: isComputed
                    )
                )
            }
        }
        return result
    }

    // MARK: - Helpers: Methods

    private func extractMethods(from memberBlock: MemberBlockSyntax) -> [Method] {
        var result: [Method] = []
        for member in memberBlock.members {
            guard let funcDecl = member.decl.as(FunctionDeclSyntax.self) else { continue }
            let access = accessLevel(from: funcDecl.modifiers)
            let isStatic = funcDecl.modifiers.contains { $0.name.text == "static" || $0.name.text == "class" }
            let name = funcDecl.name.text

            let parameters: [(label: String?, type: String)] = funcDecl.signature.parameterClause.parameters.map { param in
                let label = param.firstName.text == "_" ? nil : param.firstName.text
                let type = param.type.trimmedDescription
                return (label: label, type: type)
            }

            let returnType = funcDecl.signature.returnClause?.type.trimmedDescription

            result.append(
                Method(
                    name: name,
                    parameters: parameters,
                    returnType: returnType,
                    access: access,
                    isStatic: isStatic
                )
            )
        }
        return result
    }

    // MARK: - Helpers: Relationships

    /// Determines relationships from a type's inheritance clause and stored properties.
    private func addRelationships(
        for entityName: String,
        kind: EntityKind,
        inherited: [String],
        properties: [Property]
    ) {
        // Well-known Swift protocols that are typically noise in diagrams
        let commonProtocols: Set<String> = [
            "Codable", "Decodable", "Encodable",
            "Hashable", "Equatable", "Comparable",
            "Identifiable", "CustomStringConvertible",
            "Error", "LocalizedError", "Sendable",
        ]

        for parentName in inherited {
            if commonProtocols.contains(parentName) { continue }

            // For classes, the first inherited type could be a superclass.
            // Without full semantic info we treat all as conformance for
            // structs/enums/protocols, and the first as inheritance for classes.
            if kind == .classType, parentName == inherited.first {
                // Heuristic: if it starts with an uppercase letter and isn't
                // commonly known as a protocol, treat as class inheritance.
                relationships.append(
                    Relationship(kind: .inheritance, sourceName: entityName, targetName: parentName)
                )
            } else if kind == .protocolType {
                relationships.append(
                    Relationship(kind: .protocolInheritance, sourceName: entityName, targetName: parentName)
                )
            } else {
                relationships.append(
                    Relationship(kind: .conformance, sourceName: entityName, targetName: parentName)
                )
            }
        }

        // Association relationships from stored (non-computed) properties
        // whose type references another user-defined entity.
        for property in properties where !property.isComputed {
            guard let typeName = property.typeName else { continue }
            let cleaned = cleanTypeName(typeName)
            // Only add associations for types that look like user-defined types
            // (start with uppercase, not basic Swift types).
            if looksLikeUserType(cleaned) {
                relationships.append(
                    Relationship(kind: .association, sourceName: entityName, targetName: cleaned)
                )
            }
        }
    }

    /// Strips Optional/Array/generic wrappers to get the root type name.
    private func cleanTypeName(_ typeName: String) -> String {
        var name = typeName
            .replacingOccurrences(of: "?", with: "")
            .replacingOccurrences(of: "!", with: "")
            .trimmingCharacters(in: .whitespaces)

        // Handle Array<T> -> T
        if name.hasPrefix("[") && name.hasSuffix("]") {
            name = String(name.dropFirst().dropLast())
        }
        if name.hasPrefix("Array<") && name.hasSuffix(">") {
            name = String(name.dropFirst(6).dropLast())
        }
        // Handle Set<T>, Dictionary<K,V> -> take first generic parameter
        if let idx = name.firstIndex(of: "<") {
            let inner = String(name[name.index(after: idx)...].dropLast())
            if let comma = inner.firstIndex(of: ",") {
                name = String(inner[inner.startIndex..<comma]).trimmingCharacters(in: .whitespaces)
            } else {
                name = inner
            }
        }
        return name.trimmingCharacters(in: .whitespaces)
    }

    private func looksLikeUserType(_ name: String) -> Bool {
        let builtins: Set<String> = [
            "String", "Int", "Double", "Float", "Bool", "Data", "Date",
            "URL", "UUID", "CGFloat", "CGPoint", "CGSize", "CGRect",
            "Any", "AnyObject", "Void", "Never", "some", "Self",
            "Int8", "Int16", "Int32", "Int64",
            "UInt", "UInt8", "UInt16", "UInt32", "UInt64",
            "Character", "Substring",
        ]
        guard let first = name.first else { return false }
        return first.isUppercase && !builtins.contains(name)
    }
}
