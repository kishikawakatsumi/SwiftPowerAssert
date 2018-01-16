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

class SourceFormatterTests: XCTestCase {
    func testSourceTokenizer() {
        let formatter = SourceFormatter()

        XCTAssertEqual(formatter.format(source:
            "assert([one,  two,   \"three\"].index(of: zero) == two)"),
                       "assert([one,  two,   \"three\"].index(of: zero) == two)")
        XCTAssertEqual(formatter.format(source:
            """
            assert(bar
                .val ==
                bar
                    .foo        .val)
            """),
                       "assert(bar .val == bar .foo        .val)")
        XCTAssertEqual(formatter.format(source:
            """
            assert(array
                .
                index(

                    of:
                    zero)
                == two
            )
            """),
            "assert(array . index(  of: zero) == two )")
        XCTAssertEqual(formatter.format(source:
            """
            assert(array
                .description
                .hasPrefix(    "["
                )
                == false && array
                    .description
                    .hasPrefix    ("Hello"    ) ==
                true)
            """),
                       "assert(array .description .hasPrefix(    \"[\" ) == false && array .description .hasPrefix    (\"Hello\"    ) == true)")

        XCTAssertEqual(formatter.format(source:
            """
            assert(multilineLiteral != \"""
                Lorem ipsum dolor sit amet, consectetur adipiscing elit,
                sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
                \""")
            """),
            "assert(multilineLiteral != \"Lorem ipsum dolor sit amet, consectetur adipiscing elit,\\nsed do eiusmod tempor incididunt ut labore et dolore magna aliqua.\")")
        XCTAssertEqual(formatter.format(source:
            """
            assert(threeDoubleQuotationMarks == \"""
                Escaping the first quotation mark \\\"""
                Escaping all three quotation marks \\"\\"\\"
                \""")
            """),
            "assert(threeDoubleQuotationMarks == \"Escaping the first quotation mark \\\"\\\"\\\"\\nEscaping all three quotation marks \\\"\\\"\\\"\")")
    }
}
