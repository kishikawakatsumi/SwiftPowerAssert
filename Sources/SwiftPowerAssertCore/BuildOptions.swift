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

public struct BuildOptions {
    public let sdkName: String
    public let sdkRoot: String
    public let platformName: String
    public let platformTargetPrefix: String
    public let arch: String
    public let deploymentTarget: String
    public let dependencies: [URL]
    public let builtProductsDirectory: String

    public var targetTriple: String {
        let triple = Triple(arch: arch, vendor: "apple", os: platformTargetPrefix, deploymentVersion: deploymentTarget, environment: nil)
        return triple.description
    }

    public init(sdkName: String, sdkRoot: String, platformName: String, platformTargetPrefix: String, arch: String, deploymentTarget: String, dependencies: [URL], builtProductsDirectory: String) {
        self.sdkName = sdkName
        self.sdkRoot = sdkRoot
        self.platformName = platformName
        self.platformTargetPrefix = platformTargetPrefix
        self.arch = arch
        self.deploymentTarget = deploymentTarget
        self.dependencies = dependencies
        self.builtProductsDirectory = builtProductsDirectory
    }
}

public enum SDK {
    case macosx
    case iphoneos
    case iphonesimulator
    case watchos
    case watchsimulator
    case appletvos
    case appletvsimulator

    public var name: String {
        switch self {
        case .macosx:
            return "macosx"
        case .iphoneos, .iphonesimulator:
            return "iphoneos"
        case .watchos, .watchsimulator:
            return "watchos"
        case .appletvos, .appletvsimulator:
            return "appletvos"
        }
    }

    public var os: String {
        switch self {
        case .macosx:
            return "macosx"
        case .iphoneos, .iphonesimulator:
            return "ios"
        case .watchos, .watchsimulator:
            return "watchos"
        case .appletvos, .appletvsimulator:
            return "tvos"
        }
    }

    public func path() -> String {
        let shell = Process(arguments: ["/usr/bin/xcrun", "--sdk", "\(self)", "--show-sdk-path"])
        try! shell.launch()
        let result = try! shell.waitUntilExit().utf8Output()
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func version() -> String {
        let shell = Process(arguments: ["defaults", "read", "\(path())/SDKSettings.plist", "Version"])
        try! shell.launch()
        let result = try! shell.waitUntilExit().utf8Output()
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct Triple {
    let arch: String
    let vendor: String
    let os: String
    let deploymentVersion: String?
    let environment: String?
}

extension Triple: CustomStringConvertible {
    var description: String {
        switch (deploymentVersion, environment) {
        case (let version?, let environment?):
            return "\(arch)-\(vendor)-\(os)\(version)-\(environment)"
        case (let version?, nil):
            return "\(arch)-\(vendor)-\(os)\(version)"
        case (nil, let environment?):
            return "\(arch)-\(vendor)-\(os)-\(environment)"
        case (nil, nil):
            return "\(arch)-\(vendor)-\(os)"
        }
    }
}
