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
    func run(xcarguments: [String]) throws {
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
                    throw CommandError.argumentError("xcodebuild option '\(option)' requires an argument")
                }
            case "build", "build-for-testing", "analyze", "archive", "test", "test-without-building", "install-src", "install", "clean":
                buildActions.append((index, option))
            case "-xctestrun":
                throw CommandError.argumentError("xcodebuild option '\(option)' not supported")
            default:
                break
            }
        }

        if buildActions.map({ $0.1 }).filter({ $0 == "test" || $0 == "build-for-testing" }).isEmpty {
            throw CommandError.argumentError("xcodebuild action can only be specified as 'test' or 'build-for-testing'")
        }

        let indicesToBeRemoved = buildActions.map { $0.0 } + testOnlyOptions.map{ $0.0 }
        let buildOptions = xcarguments.enumerated().filter { !indicesToBeRemoved.contains($0.offset) }.map { $0.element } + ["ONLY_ACTIVE_ARCH=NO"]

        let xcodebuild = Xcodebuild()
        do {
            try xcodebuild.build(arguments: buildOptions)
        } catch {
            throw CommandError.buildFailed(error)
        }

        let rawBuildSettings = try! xcodebuild.showBuildSettings(arguments: xcarguments + ["ONLY_ACTIVE_ARCH=NO"])
        let buildSettings = BuildSettings.parse(rawBuildSettings)
        guard let targetBuildSettings = buildSettings.values.filter({ $0.settings["PRODUCT_TYPE"] == "com.apple.product-type.bundle.unit-test" }).first else {
            throw CommandError.noUnitTestBundle
        }

        let sdkName = targetBuildSettings.settings["SDK_NAME"]!
        let sdkRoot = targetBuildSettings.settings["SDKROOT"]!
        let platformName = targetBuildSettings.settings["PLATFORM_NAME"]!
        let platformTargetPrefix = targetBuildSettings.settings["SWIFT_PLATFORM_TARGET_PREFIX"]!
        let arch = targetBuildSettings.settings["arch"]!
        let deploymentTargetSettingName = targetBuildSettings.settings["DEPLOYMENT_TARGET_SETTING_NAME"]!
        let deploymentTarget = targetBuildSettings.settings[deploymentTargetSettingName]!
        let buildDirectory = targetBuildSettings.settings["BUILT_PRODUCTS_DIR"]!

        var backupFiles = [String: TemporaryFile]()
        let temporaryDirectory = try! TemporaryDirectory(prefix: "com.kishikawakatsumi.swift-power-assert", removeTreeOnDeinit: true)
        let sources = targetBuildSettings.sources()
        for source in sources {
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: source.path, isDirectory: &isDirectory) && !isDirectory.boolValue {
                let temporaryFile = try! TemporaryFile(dir: temporaryDirectory.path, suffix: source.lastPathComponent)
                try! FileManager.default.removeItem(atPath: temporaryFile.path.asString)
                try! FileManager.default.copyItem(atPath: source.path, toPath: temporaryFile.path.asString)
                backupFiles[source.path] = temporaryFile

                let dependencies = sources.filter { $0 != source }
                let options = BuildOptions(sdkName: sdkName, sdkRoot: sdkRoot,
                                           platformName: platformName, platformTargetPrefix: platformTargetPrefix,
                                           arch: arch, deploymentTarget: deploymentTarget,
                                           dependencies: dependencies, buildDirectory: buildDirectory)
                let processor = SwiftPowerAssert(buildOptions: options)
                do {
                    let transformed = try processor.processFile(input: source)
                    if let first = sources.first, first == source {
                        try (transformed + "\n\n\n" + __DisplayWidth.myself).write(to: source, atomically: true, encoding: .utf8)
                    } else {
                        try transformed.write(to: source, atomically: true, encoding: .utf8)
                    }
                } catch {
                    throw CommandError.instrumentFailed(error)
                }
            }
        }

        do {
            try xcodebuild.invoke(arguments: xcarguments)
        } catch {
            throw CommandError.executionFailed(error)
        }

        for (original, copy) in backupFiles {
            try! FileManager.default.removeItem(atPath: original)
            try! FileManager.default.copyItem(atPath: copy.path.asString, toPath: original)
        }
    }
}

private struct Xcodebuild {
    func showBuildSettings(arguments: [String]) throws -> String {
        let command = Process(arguments: ["/usr/bin/xcrun", "xcodebuild", "-showBuildSettings"] + arguments)
        try command.launch()
        let result = try command.waitUntilExit()
        return try result.utf8Output()
    }

    func build(arguments: [String]) throws {
        try run(action: "build", arguments: arguments)
    }

    func invoke(arguments: [String]) throws {
        try run(action: nil, arguments: arguments)
    }

    private func run(action: String?, arguments: [String]) throws {
        let buildAction: [String]
        if let action = action {
            buildAction = [action]
        } else {
            buildAction = []
        }
        let command = Process(arguments: ["/usr/bin/xcrun", "xcodebuild"] + buildAction + arguments, redirectOutput: false)
        try command.launch()
        try command.waitUntilExit()
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
