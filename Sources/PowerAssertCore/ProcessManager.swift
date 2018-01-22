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
import Utility

public final class ProcessManager {
    public static let `default` = ProcessManager()

    let processSet: ProcessSet
    let interruptHandler: InterruptHandler

    private init() {
        let processSet = ProcessSet()
        interruptHandler = try! InterruptHandler {
            processSet.terminate()
            var action = sigaction()
            #if os(macOS)
            action.__sigaction_u.__sa_handler = SIG_DFL
            #else
            action.__sigaction_handler = unsafeBitCast(SIG_DFL, to: sigaction.__Unnamed_union___sigaction_handler.self)
            #endif
            sigaction(SIGINT, &action, nil)
            kill(getpid(), SIGINT)
        }
        self.processSet = processSet
    }

    public func add(process: Basic.Process) {
        try! processSet.add(process)
    }
}
