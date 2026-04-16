import ArgumentParser
import CoreLibrary
import Foundation

@main
struct DiagramCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "diagram-cli",
        abstract: "Generate Mermaid class diagrams from Swift source files.",
        discussion: """
        Scans the specified directories for .swift files, analyzes their structure
        using SwiftSyntax, and outputs a Mermaid.js class diagram.

        Examples:
          diagram-cli /path/to/Sources
          diagram-cli /path/to/Sources --output diagram.md
          diagram-cli /path/to/Sources --update-readme /path/to/README.md
        """
    )

    // MARK: - Arguments

    @Argument(help: "One or more directories or .swift files to analyze.")
    var inputs: [String]

    // MARK: - Options

    @Option(name: .shortAndLong, help: "Write the Mermaid diagram to a file instead of stdout.")
    var output: String?

    @Option(name: .long, help: "Update a README.md file by inserting the diagram between placeholder markers.")
    var updateReadme: String?

    @Option(name: .long, help: "Project name used when generating a new README. Defaults to the input directory name.")
    var projectName: String?

    @Option(name: .long, help: "Minimum access level to include: open, public, internal, fileprivate, private. Default: internal.")
    var accessLevel: String = "internal"

    @Option(name: .long, parsing: .upToNextOption, help: "Directory names to exclude from scanning.")
    var exclude: [String] = []

    // MARK: - Flags

    @Flag(name: .long, help: "Hide properties from the diagram boxes.")
    var hideProperties: Bool = false

    @Flag(name: .long, help: "Hide methods from the diagram boxes.")
    var hideMethods: Bool = false

    @Flag(name: .long, help: "Group entities by their source directory.")
    var groupByDirectory: Bool = false

    @Flag(name: .long, help: "Dry-run: print the diagram to stdout even if --output or --update-readme is specified.")
    var dryRun: Bool = false

    // MARK: - Run

    func run() throws {
        let minAccess = parseAccessLevel(accessLevel)

        var excludedDirs: Set<String> = ["Tests", "Pods", ".build", "DerivedData"]
        for dir in exclude {
            excludedDirs.insert(dir)
        }

        let config = AnalysisConfiguration(
            inputPaths: inputs,
            excludedDirectories: excludedDirs,
            minimumAccessLevel: minAccess
        )

        let analyzer = SourceAnalyzer(configuration: config)
        let result = try analyzer.analyze()

        if result.entities.isEmpty {
            print("⚠ No Swift types found in the specified paths.")
            return
        }

        let mermaidConfig = MermaidConfiguration(
            showProperties: !hideProperties,
            showMethods: !hideMethods,
            groupByDirectory: groupByDirectory
        )
        let generator = MermaidGenerator(configuration: mermaidConfig)
        let diagram = generator.generate(from: result)

        // Summary
        let entityCount = result.entities.count
        let relationshipCount = result.relationships.count
        printSummary(entityCount: entityCount, relationshipCount: relationshipCount)

        // Output
        if dryRun || (output == nil && updateReadme == nil) {
            print(diagram)
        }

        if !dryRun, let outputPath = output {
            try diagram.write(toFile: outputPath, atomically: true, encoding: .utf8)
            print("Diagram written to \(outputPath)")
        }

        if let readmePath = updateReadme {
            let name = projectName ?? URL(fileURLWithPath: inputs.first ?? ".").lastPathComponent
            let updater = ReadmeUpdater()
            try updater.update(readmePath: readmePath, mermaidDiagram: diagram, projectName: name)
            print("README updated at \(readmePath)")
        }
    }

    // MARK: - Helpers

    private func parseAccessLevel(_ value: String) -> AccessLevel {
        switch value.lowercased() {
        case "open": return .open
        case "public": return .public
        case "internal": return .internal
        case "fileprivate": return .fileprivate
        case "private": return .private
        default: return .internal
        }
    }

    private func printSummary(entityCount: Int, relationshipCount: Int) {
        print("--- StructDiagramKit Analysis ---")
        print("  Types found: \(entityCount)")
        print("  Relationships: \(relationshipCount)")
        print("---------------------------------")
    }
}
