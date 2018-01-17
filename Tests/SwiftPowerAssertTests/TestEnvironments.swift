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

class TestEnvironments {
    lazy var temporaryDirectory = {
        return try! TemporaryDirectory(prefix: "com.kishikawakatsumi.swift-power-assert", removeTreeOnDeinit: true)
    }()
    lazy var temporaryFile = {
        return try! TemporaryFile(dir: temporaryDirectory.path, prefix: "Tests", suffix: ".swift").path
    }()
    lazy var sourceFilePath = {
        return temporaryFile.asString
    }()
    lazy var utilitiesFilePath = {
        return temporaryDirectory.path.appending(component: "Utilities.swift").asString
    }()
    lazy var mainFilePath = {
        return temporaryDirectory.path.appending(component: "main.swift").asString
    }()
    lazy var executablePath = {
        return sourceFilePath + ".o"
    }()
    lazy var sdk = {
        return try! SDK.macosx.path()
    }()
    var targetTriple: String {
        #if os(macOS)
        return "x86_64-apple-macosx10.10"
        #else
        return "x86_64-unknown-linux"
        #endif
    }
    lazy var parseOptions: [String] = {
        let buildDirectory = temporaryDirectory.path.asString
        #if os(macOS)
        return [
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
        ]
        #else
        return [
            "-target",
            targetTriple,
            "-F",
            buildDirectory,
            "-I",
            buildDirectory
        ]
        #endif
    }()
    lazy var execOptions: [String] = {
        #if os(macOS)
        return [
            "/usr/bin/xcrun",
            "swiftc",
            "-O",
            "-whole-module-optimization",
            sourceFilePath,
            utilitiesFilePath,
            mainFilePath,
            "-o",
            executablePath,
            "-target",
            targetTriple,
            "-sdk",
            sdk,
            "-F",
            "\(sdk)/../../../Developer/Library/Frameworks",
            "-Xlinker",
            "-rpath",
            "-Xlinker",
            "\(sdk)/../../../Developer/Library/Frameworks",
        ]
        #else
        return [
            "swiftc",
            "-O",
            "-whole-module-optimization",
            sourceFilePath,
            utilitiesFilePath,
            mainFilePath,
            "-o",
            executablePath,
            "-target",
            targetTriple,
            "-Xlinker",
            "-rpath",
        ]
        #endif
    }()
}
