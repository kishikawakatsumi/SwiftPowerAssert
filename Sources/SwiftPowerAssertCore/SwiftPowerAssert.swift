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

public enum SwiftPowerAsserrError: Error {
    case buildFailed(String)
}

public final class SwiftPowerAssert {
    private let buildOptions: BuildOptions

    public init(buildOptions: BuildOptions) {
        self.buildOptions = buildOptions
    }

    public func processFile(input: URL) throws -> String {
        let transformer = Transformer(target: buildOptions.targetTriple, sdkRoot: buildOptions.sdkRoot)
        return try transformer.transform(sourceFile: input, dependencies: buildOptions.dependencies, buildDirectory: buildOptions.buildDirectory)
    }
}
