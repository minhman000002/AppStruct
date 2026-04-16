import Foundation
import SwiftParser
import SwiftSyntax

/// Configuration for source analysis.
public struct AnalysisConfiguration: Sendable {
    /// Directories to scan for `.swift` files.
    public let inputPaths: [String]
    /// Directory names to exclude from scanning.
    public let excludedDirectories: Set<String>
    /// Minimum access level to include in results.
    public let minimumAccessLevel: AccessLevel

    public init(
        inputPaths: [String],
        excludedDirectories: Set<String> = ["Tests", "Pods", ".build", "DerivedData"],
        minimumAccessLevel: AccessLevel = .internal
    ) {
        self.inputPaths = inputPaths
        self.excludedDirectories = excludedDirectories
        self.minimumAccessLevel = minimumAccessLevel
    }
}

/// Scans Swift source files and produces an `AnalysisResult`.
public struct SourceAnalyzer: Sendable {

    private let configuration: AnalysisConfiguration

    public init(configuration: AnalysisConfiguration) {
        self.configuration = configuration
    }

    /// Analyze all Swift files found under the configured input paths.
    public func analyze() throws -> AnalysisResult {
        let swiftFiles = try collectSwiftFiles()

        var allEntities: [Entity] = []
        var allRelationships: [Relationship] = []

        for filePath in swiftFiles {
            let source = try String(contentsOfFile: filePath, encoding: .utf8)
            let syntaxTree = Parser.parse(source: source)

            let visitor = SwiftEntityVisitor(
                filePath: filePath,
                minimumAccessLevel: configuration.minimumAccessLevel
            )
            visitor.walk(syntaxTree)

            allEntities.append(contentsOf: visitor.entities)
            allRelationships.append(contentsOf: visitor.relationships)
        }

        // Deduplicate relationships
        var seen = Set<String>()
        let uniqueRelationships = allRelationships.filter { rel in
            let key = "\(rel.kind.rawValue)|\(rel.sourceName)|\(rel.targetName)"
            return seen.insert(key).inserted
        }

        return AnalysisResult(entities: allEntities, relationships: uniqueRelationships)
    }

    // MARK: - File Collection

    private func collectSwiftFiles() throws -> [String] {
        let fileManager = FileManager.default
        var swiftFiles: [String] = []

        for inputPath in configuration.inputPaths {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: inputPath, isDirectory: &isDirectory) else {
                continue
            }

            if isDirectory.boolValue {
                let files = try collectSwiftFilesRecursively(in: inputPath, fileManager: fileManager)
                swiftFiles.append(contentsOf: files)
            } else if inputPath.hasSuffix(".swift") {
                swiftFiles.append(inputPath)
            }
        }

        return swiftFiles.sorted()
    }

    private func collectSwiftFilesRecursively(
        in directory: String,
        fileManager: FileManager
    ) throws -> [String] {
        var result: [String] = []

        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: directory),
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return result
        }

        for case let url as URL in enumerator {
            let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey])
            if resourceValues.isDirectory == true {
                let dirName = url.lastPathComponent
                if configuration.excludedDirectories.contains(dirName) {
                    enumerator.skipDescendants()
                    continue
                }
            } else if url.pathExtension == "swift" {
                result.append(url.path)
            }
        }

        return result
    }
}
