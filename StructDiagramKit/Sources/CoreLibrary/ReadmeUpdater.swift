import Foundation

/// Handles inserting or updating Mermaid diagram blocks in a README.md file.
///
/// The updater looks for placeholder markers in the file:
/// ```
/// <!-- DIAGRAM-START -->
/// ... existing content replaced ...
/// <!-- DIAGRAM-END -->
/// ```
///
/// If the markers are not found, the diagram is appended at the end.
public struct ReadmeUpdater: Sendable {

    public static let startMarker = "<!-- DIAGRAM-START -->"
    public static let endMarker = "<!-- DIAGRAM-END -->"

    public init() {}

    /// Update the README file at `path` with the given Mermaid diagram text.
    /// If the file does not exist, a new one is created with a default template.
    public func update(readmePath: String, mermaidDiagram: String, projectName: String? = nil) throws {
        let fileManager = FileManager.default
        let content: String

        if fileManager.fileExists(atPath: readmePath) {
            content = try String(contentsOfFile: readmePath, encoding: .utf8)
        } else {
            content = defaultTemplate(projectName: projectName ?? "Project")
        }

        let updated = replaceDiagramBlock(in: content, with: mermaidDiagram)
        try updated.write(toFile: readmePath, atomically: true, encoding: .utf8)
    }

    /// Replace the content between the start and end markers, or append if not found.
    func replaceDiagramBlock(in content: String, with mermaidDiagram: String) -> String {
        let diagramBlock = """
        \(Self.startMarker)

        ## Architecture Diagram

        ```mermaid
        \(mermaidDiagram)
        ```

        \(Self.endMarker)
        """

        // Try to find and replace existing block
        if let startRange = content.range(of: Self.startMarker),
           let endRange = content.range(of: Self.endMarker)
        {
            let replaceRange = startRange.lowerBound..<endRange.upperBound
            var updated = content
            updated.replaceSubrange(replaceRange, with: diagramBlock)
            return updated
        }

        // Markers not found — append the diagram at the end
        return content + "\n\n" + diagramBlock + "\n"
    }

    /// A minimal README template for new projects.
    private func defaultTemplate(projectName: String) -> String {
        """
        # \(projectName)

        > Auto-generated project documentation.

        ## Overview

        This project is written in Swift.

        \(Self.startMarker)
        \(Self.endMarker)

        ## Getting Started

        1. Clone the repository.
        2. Open the `.xcodeproj` or `Package.swift` in Xcode.
        3. Build and run.
        """
    }
}
