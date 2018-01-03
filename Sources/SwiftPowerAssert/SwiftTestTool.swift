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
import SwiftPowerAssertCore

struct SwiftTestTool {
    func run(arguments: [String], verbose: Bool = false) throws {
        print("Reading project settings...")
        let swiftPackage = SwiftPackage()
        let rawPackageDescription = try swiftPackage.describe()

        let packageDescription = try JSONDecoder().decode(PackageDescription.self, from: rawPackageDescription.data(using: .utf8)!)
        let testTypeTergets = packageDescription.targets.filter { $0.type == "test" }

        guard !testTypeTergets.isEmpty else {
            throw SwiftPowerAssertError.noUnitTestBundle
        }

        let swiftBuild = SwiftBuild()
        try swiftBuild.build(arguments: [])

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

        let buildPath = URL(fileURLWithPath: "./.build")
        let hostTriple = Triple.hostTriple
        let triple = hostTriple.tripleString
        let configuration = "debug"

        let sdk = SDK.macosx
        let sdkName = sdk.name
        let sdkRoot = try! sdk.path()
        let platformName = sdkName
        let platformTargetPrefix = platformName
        let arch = hostTriple.arch.rawValue
        let deploymentTarget = "10.10"
        let builtProductsDirectory = buildPath.appendingPathComponent(triple).appendingPathComponent(configuration).path
        
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
                    let options = BuildOptions(sdkName: sdkName, sdkRoot: sdkRoot,
                                               platformName: platformName, platformTargetPrefix: platformTargetPrefix,
                                               arch: arch, deploymentTarget: deploymentTarget,
                                               dependencies: dependencies, builtProductsDirectory: builtProductsDirectory)
                    let processor = SwiftPowerAssert(buildOptions: options)
                    let transformed = try processor.processFile(input: source, verbose: verbose)
                    do {
                        if let first = sources.first, first == source {
                            try (transformed + "\n\n\n" + __DisplayWidth.myself).write(to: source, atomically: true, encoding: .utf8)
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
            try swiftTest.test(arguments: arguments)
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

    func describe() throws -> String {
        let command = Process(arguments: exec + ["describe", "--type", "json"])
        try! command.launch()
        let result = try! command.waitUntilExit()
        let output = try! result.utf8Output()
        switch result.exitStatus {
        case .terminated(let code) where code == 0:
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
    let exec = ["/usr/bin/xcrun", "swift"]

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

private struct Triple {
    public let tripleString: String

    public let arch: Arch
    public let vendor: Vendor
    public let os: OS
    public let abi: ABI

    public enum Error: Swift.Error {
        case badFormat
        case unknownArch
        case unknownOS
    }

    public enum Arch: String {
        case x86_64
        case armv7
        case s390x
    }

    public enum Vendor: String {
        case unknown
        case apple
    }

    public enum OS: String {
        case darwin
        case macOS = "macosx"
        case linux

        fileprivate static let allKnown:[OS] = [
            .darwin,
            .macOS,
            .linux
        ]
    }

    public enum ABI: String {
        case unknown
        case android = "androideabi"
    }

    public init(_ string: String) throws {
        let components = string.split(separator: "-").map(String.init)

        guard components.count == 3 || components.count == 4 else {
            throw Error.badFormat
        }

        guard let arch = Arch(rawValue: components[0]) else {
            throw Error.unknownArch
        }

        let vendor = Vendor(rawValue: components[1]) ?? .unknown

        guard let os = Triple.parseOS(components[2]) else {
            throw Error.unknownOS
        }

        let abiString = components.count > 3 ? components[3] : nil
        let abi = abiString.flatMap(ABI.init)

        self.tripleString = string
        self.arch = arch
        self.vendor = vendor
        self.os = os
        self.abi = abi ?? .unknown
    }

    fileprivate static func parseOS(_ string: String) -> OS? {
        for candidate in OS.allKnown {
            if string.hasPrefix(candidate.rawValue) {
                return candidate
            }
        }

        return nil
    }

    public func isDarwin() -> Bool {
        return vendor == .apple || os == .macOS || os == .darwin
    }

    public func isLinux() -> Bool {
        return os == .linux
    }

    public static let macOS = try! Triple("x86_64-apple-macosx10.10")
    public static let linux = try! Triple("x86_64-unknown-linux")
    public static let android = try! Triple("armv7-unknown-linux-androideabi")

  #if os(macOS)
    public static let hostTriple: Triple = .macOS
  #elseif os(Linux) && arch(s390x)
    public static let hostTriple: Triple = try! Triple("s390x-unknown-linux")
  #else
    public static let hostTriple: Triple = .linux
  #endif
}
