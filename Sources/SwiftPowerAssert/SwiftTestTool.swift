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
        var swiftTestArguments: [String]
        if let first = arguments.first, first == "swift" {
            swiftTestArguments = Array(arguments.dropFirst())
        } else {
            swiftTestArguments = arguments
        }

        if let command = swiftTestArguments.first, !command.hasPrefix("-") {
            guard command == "test" else {
                throw SwiftPowerAssertError.invalidArgument("only 'test' swift subcommand is supported.")
            }
            swiftTestArguments = Array(swiftTestArguments.dropFirst())
        }

        var iterator = swiftTestArguments.makeIterator()
        var configurationArgument: String?
        var buildPathArgument: String?
        var packagePathArgument: String?
        while let option = iterator.next() {
            switch option {
            case "--configuration", "-c":
                configurationArgument = iterator.next()
            case "--build-path":
                buildPathArgument = iterator.next()
            case "--package-path":
                packagePathArgument = iterator.next()
            default:
                break
            }
        }

        print("Reading project settings...")
        let swiftPackage = SwiftPackage()
        let rawPackageDescription = try swiftPackage.describe(packagePath: packagePathArgument, buildPath: buildPathArgument)

        let packageDescription = try JSONDecoder().decode(PackageDescription.self, from: rawPackageDescription.data(using: .utf8)!)
        let testTypeTergets = packageDescription.targets.filter { $0.type == "test" }

        guard !testTypeTergets.isEmpty else {
            throw SwiftPowerAssertError.noUnitTestBundle
        }

        print("Build projedt target and dependencies...")
        let swiftBuild = SwiftBuild()
        var swiftBuildArgument = [String]()
        if let configurationArgument = configurationArgument {
            swiftBuildArgument.append(contentsOf: ["--configuration", configurationArgument])
        }
        if let buildPathArgument = buildPathArgument {
            swiftBuildArgument.append(contentsOf: ["--build-path", buildPathArgument])
        }
        if let packagePathArgument = packagePathArgument {
            swiftBuildArgument.append(contentsOf: ["--package-path", packagePathArgument])
        }
        try swiftBuild.build(arguments: swiftBuildArgument)

        let temporaryDirectory: TemporaryDirectory
        do {
            temporaryDirectory = try TemporaryDirectory(prefix: "com.kishikawakatsumi.swift-power-assert", removeTreeOnDeinit: true)
        } catch {
            throw SwiftPowerAssertError.writeFailed("unable to create backup directory", error)
        }
        var backupFiles = [String: TemporaryFile]()
        defer {
            restoreOriginalSourceFiles(from: backupFiles)
        }

        let buildPath: URL
        if let buildPathArgument = buildPathArgument {
            buildPath = URL(fileURLWithPath: buildPathArgument)
        } else {
            if let packagePathArgument = packagePathArgument {
                buildPath = URL(fileURLWithPath: packagePathArgument).appendingPathComponent(".build")
            } else {
                buildPath = URL(fileURLWithPath: "./.build")
            }
        }

        let configuration: String
        if let configurationArgument = configurationArgument {
            configuration = configurationArgument
        } else {
            configuration = "debug"
        }

        let sdk = try! SDK.macosx.path()
        let targetTriple = "x86_64-apple-macosx10.10"
        let buildDirectory = buildPath.appendingPathComponent(targetTriple).appendingPathComponent(configuration).path

        let rawDependencies = try swiftPackage.showDependencies(packagePath: packagePathArgument, buildPath: buildPathArgument)

        let dependency = try! JSONDecoder().decode(Dependency.self, from: rawDependencies.data(using: .utf8)!)

        var modulemapPaths = [String]()
        func findModules(_ dependencies: [Dependency]) {
            for dependency in dependencies {
                var isDirectory: ObjCBool = false
                let modulemapPath = URL(fileURLWithPath: dependency.path).appendingPathComponent("module.modulemap").path
                if FileManager.default.fileExists(atPath: modulemapPath, isDirectory: &isDirectory) && !isDirectory.boolValue {
                    modulemapPaths.append(modulemapPath)
                }
                findModules(dependency.dependencies)
            }
        }
        findModules(dependency.dependencies)

        let swiftArguments = [
            "-sdk",
            sdk,
            "-target",
            targetTriple,
            "-F",
            sdk + "/../../../Developer/Library/Frameworks",
            "-F",
            buildDirectory,
            "-I",
            buildDirectory
        ] + modulemapPaths.flatMap { ["-Xcc", "-fmodule-map-file=\($0)"] }

        for testTypeTerget in testTypeTergets {
            let path = URL(fileURLWithPath: testTypeTerget.path)
            let sources = testTypeTerget.sources.map { path.appendingPathComponent($0) }
            for source in sources {
                var isDirectory: ObjCBool = false
                if FileManager.default.fileExists(atPath: source.path, isDirectory: &isDirectory) && !isDirectory.boolValue {
                    do {
                        let temporaryFile = try TemporaryFile(dir: temporaryDirectory.path, prefix: "Backup", suffix: source.lastPathComponent)
                        try FileManager.default.removeItem(atPath: temporaryFile.path.asString)
                        try FileManager.default.copyItem(atPath: source.path, toPath: temporaryFile.path.asString)
                        backupFiles[source.path] = temporaryFile
                    } catch {
                        throw SwiftPowerAssertError.writeFailed("unable to backup source files", error)
                    }

                    print("\tProcessing: \(source.lastPathComponent)")
                    let dependencies = sources.filter { $0 != source }
                    let processor = SwiftPowerAssert(buildOptions: swiftArguments + ["-module-name", testTypeTerget.name], dependencies: dependencies)
                    let transformed = try processor.processFile(input: source, verbose: verbose)
                    do {
                        if let first = sources.first, first == source {
                            try (transformed + "\n\n\n" + __Util.source).write(to: source, atomically: true, encoding: .utf8)
                        } else {
                            try transformed.write(to: source, atomically: true, encoding: .utf8)
                        }
                    } catch {
                        throw SwiftPowerAssertError.writeFailed("failed to instrument file", error)
                    }
                }
            }

            print("Testing \(testTypeTerget.name) ...")
            let swiftTest = SwiftTest()
            try swiftTest.test(arguments: swiftTestArguments)
        }
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

private struct SwiftPackage {
    let exec = ["/usr/bin/xcrun", "swift", "package"]

    func describe(packagePath: String?, buildPath: String?) throws -> String {
        var packageOptions = [String]()
        if let packagePath = packagePath {
            packageOptions.append(contentsOf: ["--package-path", packagePath])
        }
        if let buildPath = buildPath {
            packageOptions.append(contentsOf: ["--build-path", buildPath])
        }
        let command = Process(arguments: exec + packageOptions + ["describe", "--type", "json"])
        try! command.launch()
        let result = try! command.waitUntilExit()
        let output = try! result.utf8Output()
        switch result.exitStatus {
        case .terminated(let code) where code == 0:
            let index = output.index { $0 == "{" }
            if let index = index {
                return String(output[index...])
            }
            return output
        default:
            throw SwiftPowerAssertError.taskError("failed to run the following command: '\(command.arguments.joined(separator: " "))'")
        }
    }

    func showDependencies(packagePath: String?, buildPath: String?) throws -> String {
        var packageOptions = [String]()
        if let packagePath = packagePath {
            packageOptions.append(contentsOf: ["--package-path", packagePath])
        }
        if let buildPath = buildPath {
            packageOptions.append(contentsOf: ["--build-path", buildPath])
        }
        let command = Process(arguments: exec + packageOptions + ["show-dependencies", "--format", "json"])
        try! command.launch()
        let result = try! command.waitUntilExit()
        let output = try! result.utf8Output()
        switch result.exitStatus {
        case .terminated(let code) where code == 0:
            let index = output.index { $0 == "{" }
            if let index = index {
                return String(output[index...])
            }
            return output
        default:
            throw SwiftPowerAssertError.taskError("failed to run the following command: '\(command.arguments.joined(separator: " "))'")
        }
    }
}

private struct SwiftBuild {
    let exec = ["/usr/bin/xcrun", "swift", "build"]

    func build(arguments: [String]) throws {
        let command = Process(arguments: exec + arguments, redirectOutput: false)
        try! command.launch()
        let result = try! command.waitUntilExit()
        switch result.exitStatus {
        case .terminated(let code) where code == 0:
            return
        default:
            throw SwiftPowerAssertError.taskError("failed to run the following command: '\(command.arguments.joined(separator: " "))'")
        }
    }
}

private struct SwiftTest {
    let exec = ["/usr/bin/xcrun", "swift", "test"]

    func test(arguments: [String]) throws {
        let command = Process(arguments: exec + arguments, redirectOutput: false)
        try! command.launch()
        let result = try! command.waitUntilExit()
        switch result.exitStatus {
        case .terminated(let code) where code == 0:
            return
        default:
            throw SwiftPowerAssertError.taskError("failed to run the following command: '\(command.arguments.joined(separator: " "))'")
        }
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
