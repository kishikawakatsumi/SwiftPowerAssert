////////////////////////////////////////////////////////////////////////////
//
// Copyright 2017 Kishikawa Katsumi.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
////////////////////////////////////////////////////////////////////////////

import Foundation
import Basic
import PowerAssertCore

struct SwiftTestTool {
    func run(arguments: [String], verbose: Bool = false) throws {
        let options = try SwiftTestOptions(arguments)

        print("Reading project settings...")
        let swiftPackage = SwiftPackage(packagePath: options.packagePath, buildPath: options.buildPath)
        let packageDescription = try swiftPackage.describe(verbose: verbose)

        let testTypeTergets = packageDescription.targets.filter { $0.type == "test" }
        guard !testTypeTergets.isEmpty else { throw SwiftTestError.noUnitTestBundleFound }

        let dependency = try swiftPackage.showDependencies(verbose: verbose)
        let swiftOptions = constructSwiftOptions(swiftTestOptions: options, dependency: dependency)

        print("Build project target and dependencies...")
        let swiftBuild = SwiftBuild()
        try swiftBuild.build(arguments: options.rawOptions, verbose: verbose)

        let temporaryDirectory = try TemporaryDirectory(prefix: "com.kishikawakatsumi.swift-power-assert", removeTreeOnDeinit: true)
        var backupFiles = [String: TemporaryFile]()
        defer { restoreOriginalSourceFiles(from: backupFiles) }

        print("Transforming test files...")
        for testTypeTerget in testTypeTergets {
            let path = URL(fileURLWithPath: testTypeTerget.path)
            let sources = testTypeTerget.sources.map { path.appendingPathComponent($0) }
            for source in sources {
                if Basic.localFileSystem.exists(AbsolutePath(source.path)) && Basic.localFileSystem.isFile(AbsolutePath(source.path)) {
                    let temporaryFile = try TemporaryFile(dir: temporaryDirectory.path, prefix: "Backup", suffix: source.lastPathComponent)
                    try FileManager.default.removeItem(atPath: temporaryFile.path.asString)
                    try FileManager.default.copyItem(atPath: source.path, toPath: temporaryFile.path.asString)
                    backupFiles[source.path] = temporaryFile

                    print("  Processing: \(source.lastPathComponent)")
                    let dependencies = sources.filter { $0 != source }
                    let processor = SwiftPowerAssert(buildOptions: swiftOptions + ["-module-name", testTypeTerget.name], dependencies: dependencies)
                    let transformed = try processor.processFile(input: source, verbose: verbose)

                    if let first = sources.first, first == source {
                        try (transformed + "\n\n\n" + __Util.source).write(to: source, atomically: true, encoding: .utf8)
                    } else {
                        try transformed.write(to: source, atomically: true, encoding: .utf8)
                    }
                }
            }

            print("Testing \(testTypeTerget.name) ...")
            let swiftTest = SwiftTest()
            try swiftTest.test(arguments: options.rawOptions, verbose: verbose)
        }
    }

    private func constructSwiftOptions(swiftTestOptions: SwiftTestOptions, dependency: Dependency) -> [String] {
        let configuration = swiftTestOptions.configuration ?? "debug"

        let buildPath: URL
        if let buildPathOption = swiftTestOptions.buildPath {
            buildPath = URL(fileURLWithPath: buildPathOption)
        } else {
            if let packagePath = swiftTestOptions.packagePath {
                buildPath = URL(fileURLWithPath: packagePath).appendingPathComponent(".build")
            } else {
                buildPath = URL(fileURLWithPath: "./.build")
            }
        }
        let buildDirectory = buildPath.appendingPathComponent(configuration).path

        let fileSystem = Basic.localFileSystem
        var modulemapPaths = [String]()
        func findModules(_ dependencies: [Dependency]) {
            for dependency in dependencies {
                let modulemapPath = URL(fileURLWithPath: dependency.path).appendingPathComponent("module.modulemap").path
                if fileSystem.exists(AbsolutePath(modulemapPath)) && fileSystem.isFile(AbsolutePath(modulemapPath)) {
                    modulemapPaths.append(modulemapPath)
                }
                findModules(dependency.dependencies)
            }
        }
        findModules(dependency.dependencies)

        var buildOptions = [String]()
        #if os(macOS)
        let sdk = try! SDK.macosx.path()
        buildOptions = ["-sdk", sdk, "-F", sdk + "/../../../Developer/Library/Frameworks"]
        let targetTriple = "x86_64-apple-macosx10.10"
        #else
        let targetTriple = "x86_64-unknown-linux"
        #endif
        buildOptions += ["-target", targetTriple, "-F", buildDirectory, "-I", buildDirectory]
        buildOptions += modulemapPaths.flatMap { ["-Xcc", "-fmodule-map-file=\($0)"] }

        return buildOptions
    }

    private func restoreOriginalSourceFiles(from backupFiles: [String: TemporaryFile]) {
        for (original, copy) in backupFiles {
            do {
                try FileManager.default.removeItem(atPath: original)
                try FileManager.default.copyItem(atPath: copy.path.asString, toPath: original)
            } catch {
                print(error.localizedDescription)
            }
        }
    }
}

struct SwiftTestOptions {
    var configuration: String?
    var buildPath: String?
    var packagePath: String?
    var rawOptions: [String]

    var buildOptions: [String] {
        var options = [String]()
        if let configuration = configuration {
            options.append(contentsOf: ["--configuration", configuration])
        }
        if let buildPath = buildPath {
            options.append(contentsOf: ["--build-path", buildPath])
        }
        if let packagePath = packagePath {
            options.append(contentsOf: ["--package-path", packagePath])
        }
        return options
    }

    init(_ arguments: [String]) throws {
        var options: [String]
        if let first = arguments.first, first == "swift" {
            options = Array(arguments.dropFirst())
        } else {
            options = arguments
        }
        if let subcommand = options.first, !subcommand.hasPrefix("-") {
            guard subcommand == "test" else {
                throw SwiftTestError.subcommandNotSupported(subcommand)
            }
            options = Array(options.dropFirst())
        }
        rawOptions = options

        var iterator = options.makeIterator()
        while let option = iterator.next() {
            switch option {
            case "--configuration", "-c":
                configuration = iterator.next()
            case "--build-path":
                buildPath = iterator.next()
            case "--package-path":
                packagePath = iterator.next()
            default:
                break
            }
        }
    }
}

private class SwiftTool {
    #if os(macOS)
    let exec = ["/usr/bin/xcrun", "swift"]
    #else
    let exec = ["swift"]
    #endif

    let toolName: String
    let redirectOutput: Bool

    init(toolName: String, redirectOutput: Bool = true) {
        self.toolName = toolName
        self.redirectOutput = redirectOutput
    }

    var options: [String] {
        return []
    }

    func run(_ arguments: [String], verbose: Bool = false) throws -> String {
        let command = Process(arguments: exec + [toolName] + options + arguments, redirectOutput: redirectOutput, verbose: verbose)
        try! command.launch()
        let result = try! command.waitUntilExit()
        let output = try! result.utf8Output()
        switch result.exitStatus {
        case .terminated(let code) where code == 0:
            return output
        default:
            let errorOutput = try result.utf8stderrOutput()
            throw PowerAssertError.executingSubprocessFailed(command: command.arguments.joined(separator: " "), output: errorOutput)
        }
    }
}

private class SwiftPackage: SwiftTool {
    let packagePath: String?
    let buildPath: String?

    init(packagePath: String?, buildPath: String?) {
        self.buildPath = buildPath
        self.packagePath = packagePath
        super.init(toolName: "package")
    }

    override var options: [String] {
        var options = [String]()
        if let packagePath = packagePath {
            options.append(contentsOf: ["--package-path", packagePath])
        }
        if let buildPath = buildPath {
            options.append(contentsOf: ["--build-path", buildPath])
        }
        return options
    }

    func describe(verbose: Bool = false) throws -> PackageDescription {
        let output = cleansingOutput(try run(["describe", "--type", "json"], verbose: verbose))
        return try JSONDecoder().decode(PackageDescription.self, from: output.data(using: .utf8)!)
    }

    func showDependencies(verbose: Bool = false) throws -> Dependency {
        let output = cleansingOutput(try run(["show-dependencies", "--format", "json"], verbose: verbose))
        return try! JSONDecoder().decode(Dependency.self, from: output.data(using: .utf8)!)
    }

    private func cleansingOutput(_ output: String) -> String {
        let index = output.index { $0 == "{" }
        if let index = index {
            return String(output[index...])
        }
        return output
    }
}

private class SwiftBuild: SwiftTool {
    init() {
        super.init(toolName: "build", redirectOutput: false)
    }

    func build(arguments: [String], verbose: Bool = false) throws {
        _ = try run(arguments, verbose: verbose)
    }
}

private class SwiftTest: SwiftTool {
    init() {
        super.init(toolName: "test", redirectOutput: false)
    }

    func test(arguments: [String], verbose: Bool = false) throws {
        _ = try run(arguments, verbose: verbose)
    }
}

private struct PackageDescription: Decodable {
    let name: String
    let path: String
    let targets: [Target]
}

private struct Target: Decodable {
    let c99name: String
    let moduleType: String
    let name: String
    let path: String
    let sources: [String]
    let type: String

    enum CodingKeys: String, CodingKey {
        case c99name
        case moduleType = "module_type"
        case name
        case path
        case sources
        case type
    }
}

private struct Dependency: Decodable {
    let name: String
    let path: String
    let url: String
    let version: String
    let dependencies: [Dependency]
}

private enum SwiftTestError: Error {
    case subcommandNotSupported(String)
    case noUnitTestBundleFound
}

extension SwiftTestError: CustomStringConvertible {
    var description: String {
        switch self {
        case .subcommandNotSupported(let subcommand):
            return "'swift \(subcommand)' is not supported. 'swift test' is only supported"
        case .noUnitTestBundleFound:
            return "no unit test bundle found"
        }
    }
}
