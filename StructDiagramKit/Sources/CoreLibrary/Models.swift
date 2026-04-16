import Foundation

// MARK: - Intermediate Representation (IR) Models

/// The kind of a Swift type declaration.
public enum EntityKind: String, Sendable {
    case classType = "class"
    case structType = "struct"
    case enumType = "enum"
    case protocolType = "protocol"
}

/// Access level of a member or type declaration.
public enum AccessLevel: String, Comparable, Sendable {
    case `open`
    case `public`
    case `internal`
    case `fileprivate`
    case `private`

    private var order: Int {
        switch self {
        case .open: return 0
        case .public: return 1
        case .internal: return 2
        case .fileprivate: return 3
        case .private: return 4
        }
    }

    public static func < (lhs: AccessLevel, rhs: AccessLevel) -> Bool {
        lhs.order < rhs.order
    }
}

/// A property or stored variable within a type.
public struct Property: Sendable {
    public let name: String
    public let typeName: String?
    public let access: AccessLevel
    public let isStatic: Bool
    public let isComputed: Bool

    public init(
        name: String,
        typeName: String?,
        access: AccessLevel = .internal,
        isStatic: Bool = false,
        isComputed: Bool = false
    ) {
        self.name = name
        self.typeName = typeName
        self.access = access
        self.isStatic = isStatic
        self.isComputed = isComputed
    }
}

/// A method declaration within a type.
public struct Method: Sendable {
    public let name: String
    public let parameters: [(label: String?, type: String)]
    public let returnType: String?
    public let access: AccessLevel
    public let isStatic: Bool

    public init(
        name: String,
        parameters: [(label: String?, type: String)],
        returnType: String?,
        access: AccessLevel = .internal,
        isStatic: Bool = false
    ) {
        self.name = name
        self.parameters = parameters
        self.returnType = returnType
        self.access = access
        self.isStatic = isStatic
    }
}

/// The kind of relationship between two entities.
public enum RelationshipKind: String, Sendable {
    /// Class inheritance: `class Derived: Base`
    case inheritance
    /// Protocol conformance: `struct Foo: SomeProtocol`
    case conformance
    /// Protocol inheriting another protocol
    case protocolInheritance
    /// Strong reference via a stored property
    case association
}

/// A directed relationship from one entity to another.
public struct Relationship: Sendable {
    public let kind: RelationshipKind
    public let sourceName: String
    public let targetName: String

    public init(kind: RelationshipKind, sourceName: String, targetName: String) {
        self.kind = kind
        self.sourceName = sourceName
        self.targetName = targetName
    }
}

/// A Swift type entity extracted from source code.
public struct Entity: Sendable {
    public let name: String
    public let kind: EntityKind
    public let access: AccessLevel
    public let properties: [Property]
    public let methods: [Method]
    public let inheritedTypes: [String]
    public let filePath: String?

    public init(
        name: String,
        kind: EntityKind,
        access: AccessLevel = .internal,
        properties: [Property] = [],
        methods: [Method] = [],
        inheritedTypes: [String] = [],
        filePath: String? = nil
    ) {
        self.name = name
        self.kind = kind
        self.access = access
        self.properties = properties
        self.methods = methods
        self.inheritedTypes = inheritedTypes
        self.filePath = filePath
    }
}

/// The complete analysis result containing all discovered entities and relationships.
public struct AnalysisResult: Sendable {
    public let entities: [Entity]
    public let relationships: [Relationship]

    public init(entities: [Entity], relationships: [Relationship]) {
        self.entities = entities
        self.relationships = relationships
    }
}
