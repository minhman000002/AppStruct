import Foundation

/// Configuration for Mermaid diagram generation.
public struct MermaidConfiguration: Sendable {
    /// Whether to include properties in the class boxes.
    public let showProperties: Bool
    /// Whether to include methods in the class boxes.
    public let showMethods: Bool
    /// Whether to group entities by their source file directory.
    public let groupByDirectory: Bool
    /// Common protocols to exclude from the diagram to reduce noise.
    public let excludedTypes: Set<String>

    public init(
        showProperties: Bool = true,
        showMethods: Bool = true,
        groupByDirectory: Bool = false,
        excludedTypes: Set<String> = []
    ) {
        self.showProperties = showProperties
        self.showMethods = showMethods
        self.groupByDirectory = groupByDirectory
        self.excludedTypes = excludedTypes
    }
}

/// Generates Mermaid.js class diagram syntax from an `AnalysisResult`.
public struct MermaidGenerator: Sendable {

    private let configuration: MermaidConfiguration

    public init(configuration: MermaidConfiguration = MermaidConfiguration()) {
        self.configuration = configuration
    }

    /// Generate the complete Mermaid class diagram string.
    public func generate(from result: AnalysisResult) -> String {
        var lines: [String] = ["classDiagram"]

        let filteredEntities = result.entities.filter {
            !configuration.excludedTypes.contains($0.name)
        }

        // Entity names present in the analysis (used to filter relationships)
        let entityNames = Set(filteredEntities.map(\.name))

        // Group by directory if requested
        if configuration.groupByDirectory {
            let grouped = Dictionary(grouping: filteredEntities) { entity -> String in
                guard let path = entity.filePath else { return "Unknown" }
                return URL(fileURLWithPath: path).deletingLastPathComponent().lastPathComponent
            }

            for (groupName, entities) in grouped.sorted(by: { $0.key < $1.key }) {
                lines.append("")
                lines.append("    namespace \(sanitize(groupName)) {")
                for entity in entities.sorted(by: { $0.name < $1.name }) {
                    lines.append(contentsOf: renderEntity(entity).map { "        " + $0 })
                }
                lines.append("    }")
            }
        } else {
            lines.append("")
            for entity in filteredEntities.sorted(by: { $0.name < $1.name }) {
                lines.append(contentsOf: renderEntity(entity).map { "    " + $0 })
            }
        }

        // Relationships
        let filteredRelationships = result.relationships.filter { rel in
            !configuration.excludedTypes.contains(rel.sourceName) &&
            !configuration.excludedTypes.contains(rel.targetName)
        }

        if !filteredRelationships.isEmpty {
            lines.append("")
        }

        for rel in filteredRelationships.sorted(by: { "\($0.sourceName)\($0.targetName)" < "\($1.sourceName)\($1.targetName)" }) {
            // Only emit relationships where both sides are known entities,
            // or the target is external (still useful to show).
            let line = renderRelationship(rel, knownEntities: entityNames)
            if let line { lines.append("    " + line) }
        }

        lines.append("")
        return lines.joined(separator: "\n")
    }

    // MARK: - Entity Rendering

    private func renderEntity(_ entity: Entity) -> [String] {
        var lines: [String] = []

        // Class annotation
        let annotation = entityAnnotation(entity.kind)
        if let annotation {
            lines.append("class \(entity.name) {\n")
            lines.append("    <<\(annotation)>>")
        } else {
            lines.append("class \(entity.name) {")
        }

        // Properties
        if configuration.showProperties {
            for prop in entity.properties {
                let prefix = accessPrefix(prop.access)
                let typeStr = prop.typeName.map { ": \($0)" } ?? ""
                let staticMark = prop.isStatic ? "$ " : ""
                lines.append("    \(prefix)\(staticMark)\(prop.name)\(typeStr)")
            }
        }

        // Methods
        if configuration.showMethods {
            for method in entity.methods {
                let prefix = accessPrefix(method.access)
                let staticMark = method.isStatic ? "$ " : ""
                let params = method.parameters.map { p in
                    let label = p.label.map { "\($0): " } ?? ""
                    return "\(label)\(p.type)"
                }.joined(separator: ", ")
                let ret = method.returnType.map { " \($0)" } ?? ""
                lines.append("    \(prefix)\(staticMark)\(method.name)(\(params))\(ret)")
            }
        }

        lines.append("}")
        return lines
    }

    private func entityAnnotation(_ kind: EntityKind) -> String? {
        switch kind {
        case .protocolType: return "Interface"
        case .enumType: return "Enumeration"
        case .structType: return "Struct"
        case .classType: return nil
        }
    }

    /// Maps access levels to UML-style prefixes.
    private func accessPrefix(_ access: AccessLevel) -> String {
        switch access {
        case .open, .public: return "+"
        case .internal: return "~"
        case .fileprivate, .private: return "-"
        }
    }

    // MARK: - Relationship Rendering

    private func renderRelationship(_ rel: Relationship, knownEntities: Set<String>) -> String? {
        let source = rel.sourceName
        let target = rel.targetName

        switch rel.kind {
        case .inheritance:
            // Base <|-- Derived
            return "\(target) <|-- \(source)"
        case .conformance:
            // Protocol <|.. ConformingType
            return "\(target) <|.. \(source)"
        case .protocolInheritance:
            // BaseProtocol <|-- DerivedProtocol
            return "\(target) <|-- \(source)"
        case .association:
            // Only show if the target is a known entity
            guard knownEntities.contains(target) else { return nil }
            return "\(source) --> \(target)"
        }
    }

    // MARK: - Helpers

    /// Remove characters that Mermaid doesn't allow in identifiers.
    private func sanitize(_ name: String) -> String {
        name.replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: ".", with: "_")
    }
}
