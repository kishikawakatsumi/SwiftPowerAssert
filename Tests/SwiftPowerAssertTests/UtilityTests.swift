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

import XCTest
import SwiftPowerAssertCore

class UtilityTests: XCTestCase {
    func testDisplayWidth() throws {
        XCTAssertEqual(__Util.displayWidth(of: "Katsumi Kishikawa"), 17)
        XCTAssertEqual(__Util.displayWidth(of: "岸川克己"), 8)
        XCTAssertEqual(__Util.displayWidth(of: "岸川 克己"), 9)
        XCTAssertEqual(__Util.displayWidth(of: "岸川克己😇"), 10)
        XCTAssertEqual(__Util.displayWidth(of: "岸川 克己😇"), 11)
        XCTAssertEqual(__Util.displayWidth(of: "😇岸川克己🇯🇵"), 12)
        XCTAssertEqual(__Util.displayWidth(of: "😇岸川 克己🇯🇵"), 13)

        XCTAssertEqual(__Util.displayWidth(of: "👩‍👩‍👧‍👧岸川👨‍👨‍👦‍👦克己🇯🇵"), 14)
        XCTAssertEqual(__Util.displayWidth(of: "​​​​岸川👨‍👨‍👦‍👦克己🇯🇵"), 12)
        XCTAssertEqual(__Util.displayWidth(of: "​​​​岸川克己"), 8)
    }
}
