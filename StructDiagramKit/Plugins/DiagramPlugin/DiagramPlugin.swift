import Foundation
import PackagePlugin

/// A Swift Package Manager command plugin that generates Mermaid class diagrams
/// from Swift source files in the target package.
///
/// Users can invoke this plugin from the command line:
/// ```
/// swift package --allow-writing-to-package-directory generate-diagram
/// ```
///
/// Or by right-clicking a package target in Xcode's navigator.
@main
struct DiagramPlugin: CommandPlugin {

    func performCommand(context: PluginContext, arguments: [String]) throws {
        let tool = try context.tool(named: "DiagramCLI")

        var inputPaths: [String] = []
        for target in context.package.targets {
            guard let sourceModule = target as? SourceModuleTarget else { continue }
            inputPaths.append(sourceModule.directory.string) // swiftlint:disable:this deprecated
        }

        guard !inputPaths.isEmpty else {
            print("No source targets found in the package.")
            return
        }

        var cliArguments = inputPaths

        let readmePath = context.package.directory.appending("README.md").string
        cliArguments += ["--update-readme", readmePath]
        cliArguments += ["--project-name", context.package.displayName]
        cliArguments += arguments

        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool.path.string)
        process.arguments = cliArguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: outputData, encoding: .utf8), !output.isEmpty {
            print(output)
        }

        guard process.terminationStatus == 0 else {
            Diagnostics.error("diagram-cli exited with status \(process.terminationStatus)")
            return
        }
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension DiagramPlugin: XcodeCommandPlugin {

    func performCommand(context: XcodePluginContext, arguments: [String]) throws {
        let tool = try context.tool(named: "DiagramCLI")

        var inputPaths: [String] = []
        for target in context.xcodeProject.targets {
            for file in target.inputFiles where file.path.extension == "swift" {
                let dir = file.path.removingLastComponent().string
                if !inputPaths.contains(dir) {
                    inputPaths.append(dir)
                }
            }
        }

        guard !inputPaths.isEmpty else {
            print("No Swift source files found in the Xcode project.")
            return
        }

        var cliArguments = inputPaths

        let readmePath = context.xcodeProject.directory.appending("README.md").string
        cliArguments += ["--update-readme", readmePath]
        cliArguments += ["--project-name", context.xcodeProject.displayName]
        cliArguments += arguments

        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool.path.string)
        process.arguments = cliArguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: outputData, encoding: .utf8), !output.isEmpty {
            print(output)
        }

        guard process.terminationStatus == 0 else {
            Diagnostics.error("diagram-cli exited with status \(process.terminationStatus)")
            return
        }
    }
}
#endif
