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

struct TestCommand {
    func run(xcarguments arguments: [String], verbose: Bool = false) throws {
        let xcarguments: [String]
        if let first = arguments.first, first == "xcodebuild" {
            xcarguments = Array(arguments.dropFirst())
        } else {
            xcarguments = arguments
        }
        var iterator = xcarguments.enumerated().makeIterator()
        var buildActions = [(Int, String)]()
        var testOnlyOptions = [(Int, String)]()
        while let (index, option) = iterator.next() {
            switch option {
            case "-project", "-target", "-workspace", "-scheme", "-configuration", "-xcconfig", "-toolchain", "-find-executable",
                 "-find-library", "-resultBundlePath", "-derivedDataPath", "-archivePath", "-exportOptionsPlist":
                _ = iterator.next()
            case "-enableCodeCoverage", "-testLanguage", "-testRegion":
                testOnlyOptions.append((index, option))
                if let argument = iterator.next() {
                    testOnlyOptions.append(argument)
                } else {
                    throw SwiftPowerAssertError.invalidArgument("xcodebuild option '\(option)' requires an argument")
                }
            case "build", "build-for-testing", "analyze", "archive", "test", "test-without-building", "install-src", "install", "clean":
                buildActions.append((index, option))
            case "-xctestrun":
                throw SwiftPowerAssertError.invalidArgument("xcodebuild option '\(option)' not supported")
            default:
                break
            }
        }

        if buildActions.map({ $0.1 }).filter({ $0 == "test" || $0 == "build-for-testing" }).isEmpty {
            throw SwiftPowerAssertError.invalidArgument("xcodebuild action can only be specified as 'test' or 'build-for-testing'")
        }

        let indicesToBeRemoved = buildActions.map { $0.0 } + testOnlyOptions.map{ $0.0 }
        let buildOptions = xcarguments.enumerated().filter { !indicesToBeRemoved.contains($0.offset) }.map { $0.element } + ["ONLY_ACTIVE_ARCH=NO"]

        let xcodebuild = Xcodebuild()
        try xcodebuild.build(arguments: buildOptions)

        let rawBuildSettings = try xcodebuild.showBuildSettings(arguments: xcarguments + ["ONLY_ACTIVE_ARCH=NO"])
        let buildSettings = BuildSettings.parse(rawBuildSettings)
        guard let targetBuildSettings = buildSettings.values.filter({ $0.settings["PRODUCT_TYPE"] == "com.apple.product-type.bundle.unit-test" }).first else {
            throw SwiftPowerAssertError.noUnitTestBundle
        }

        let sdkName = targetBuildSettings.settings["SDK_NAME"]!
        let sdkRoot = targetBuildSettings.settings["SDKROOT"]!
        let platformName = targetBuildSettings.settings["PLATFORM_NAME"]!
        let platformTargetPrefix = targetBuildSettings.settings["SWIFT_PLATFORM_TARGET_PREFIX"]!
        let arch = targetBuildSettings.settings["arch"]!
        let deploymentTargetSettingName = targetBuildSettings.settings["DEPLOYMENT_TARGET_SETTING_NAME"]!
        let deploymentTarget = targetBuildSettings.settings[deploymentTargetSettingName]!
        let builtProductsDirectory = targetBuildSettings.settings["BUILT_PRODUCTS_DIR"]!

        var backupFiles = [String: TemporaryFile]()
        defer {
            restoreOriginalSourceFiles(from: backupFiles)
        }

        let temporaryDirectory: TemporaryDirectory
        do {
            temporaryDirectory = try TemporaryDirectory(prefix: "com.kishikawakatsumi.swift-power-assert", removeTreeOnDeinit: true)
        } catch {
            throw SwiftPowerAssertError.writeFailed("unable to create backup directory", error)
        }
        let sources = targetBuildSettings.sources()
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

        try xcodebuild.invoke(arguments: xcarguments)
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

private struct Xcodebuild {
    var exec = ["/usr/bin/xcrun", "xcodebuild"]

    func build(arguments: [String]) throws {
        let command = Process(arguments: exec + ["build"] + arguments, redirectOutput: false)
        try! command.launch()
        let result = try! command.waitUntilExit()
        switch result.exitStatus {
        case .terminated(let code) where code == 0:
            return
        default:
            throw SwiftPowerAssertError.taskError("failed to run the following command: '\(command.arguments.joined(separator: " "))'")
        }
    }

    func showBuildSettings(arguments: [String]) throws -> String {
        let command = Process(arguments: exec + arguments + ["-showBuildSettings"], redirectOutput: false)
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

    func invoke(arguments: [String]) throws {
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

private struct BuildSettings {
    let action: String
    let target: String
    let settings: [String: String]

    static func parse(_ rawBuildSettings: String) -> [String: BuildSettings] {
        var buildSettings = [String: BuildSettings]()

        var action: String?
        var target: String?
        var settings = [String: String]()

        let regex = try! NSRegularExpression(pattern: "^Build settings for action (\\S+) and target \\\"?([^\":]+)\\\"?:$", options: [.caseInsensitive, .anchorsMatchLines])
        rawBuildSettings.enumerateLines { (line, stop) in
            if let result = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
                if let target = target, let action = action {
                    buildSettings[target] = BuildSettings(action: action, target: target, settings: settings)
                }
                action = String(line[Range(result.range(at: 1), in: line)!])
                guard action == "test" || action == "build-for-testing" else {
                    print("swift-power-assert: error: xcodebuild action can only be specified as 'test' or 'build-for-testing'")
                    exit(1)
                }
                target = String(line[Range(result.range(at: 2), in: line)!])
                return
            }

            let components = line.split(separator: "=").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            if components.count == 2 {
                settings[components[0]] = components[1]
            }
        }
        if let target = target, let action = action {
            buildSettings[target] = BuildSettings(action: action, target: target, settings: settings)
        }

        return buildSettings
    }

    fileprivate func sources() -> [URL] {
        var sources = [Foundation.URL]()

        let projectFilePath = settings["PROJECT_FILE_PATH"]!
        let pbxprojData = try! Data(contentsOf: URL(fileURLWithPath: projectFilePath).appendingPathComponent("project.pbxproj"))
        let pbxproj = try? PropertyListSerialization.propertyList(from: pbxprojData, options: [], format: nil)
        if let pbxproj = pbxproj as? [String: Any] {
            if let rootObjectID = pbxproj["rootObject"] as? String, let objects = pbxproj["objects"] as? [String: Any], let rootObject = objects[rootObjectID] as? [String: Any] {
                if let targetIDs = rootObject["targets"] as? [String] {
                    for targetID in targetIDs {
                        if let targetObject = objects[targetID] as? [String: Any], let name = targetObject["name"] as? String, let productType = targetObject["productType"] as? String {
                            if name == target && productType == settings["PRODUCT_TYPE"] {
                                if let buildPhaseIDs = targetObject["buildPhases"] as? [String] {
                                    for buildPhaseID in buildPhaseIDs {
                                        if let buildPhase = objects[buildPhaseID] as? [String: Any], let isa = buildPhase["isa"] as? String, isa == "PBXSourcesBuildPhase", let fileIDs = buildPhase["files"] as? [String] {
                                            for fileID in fileIDs {
                                                if let fileObject = objects[fileID] as? [String: Any], let isa = fileObject["isa"] as? String, isa == "PBXBuildFile", let fileRefID = fileObject["fileRef"] as? String, let fileRefObject = objects[fileRefID] as? [String: Any] {
                                                    if let isa = fileRefObject["isa"] as? String, isa == "PBXFileReference", let path = fileRefObject["path"] as? String {
                                                        let groupPaths = parentGroupPaths(objects: objects, targetGroupID: fileRefID)
                                                        var sourceRoot = URL(fileURLWithPath: settings["SRCROOT"]!)
                                                        for groupPath in groupPaths {
                                                            sourceRoot.appendPathComponent(groupPath)
                                                        }
                                                        sourceRoot.appendPathComponent(path)
                                                        sources.append(sourceRoot)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        return sources
    }

    private func parentGroupPaths(objects: [String: Any], targetGroupID: String) -> [String] {
        var paths = [String]()
        for groupID in objects.keys {
            if let group = objects[groupID] as? [String: Any], let isa = group["isa"] as? String, isa == "PBXGroup" {
                if let children = group["children"] as? [String], children.contains(targetGroupID), let path = group["path"] as? String {
                    paths.append(path)
                    return parentGroupPaths(objects: objects, targetGroupID: groupID) + paths
                }
            }
        }
        return paths
    }
}
