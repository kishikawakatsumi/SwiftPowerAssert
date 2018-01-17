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
@testable import SwiftPowerAssertTests

extension AssertTests {
    static var allTests: [(String, (AssertTests) -> () throws -> Void)] = [
        ("testBinaryExpression1()", testBinaryExpression1),
        ("testBinaryExpression2()", testBinaryExpression2),
        ("testBinaryExpression3()", testBinaryExpression3),
        ("testBinaryExpression4()", testBinaryExpression4),
        ("testBinaryExpression5()", testBinaryExpression5),
        ("testBinaryExpression6()", testBinaryExpression6),
        ("testBinaryExpression7()", testBinaryExpression7),
        ("testBinaryExpression8()", testBinaryExpression8),
        ("testMultilineExpression1()", testMultilineExpression1),
        ("testMultilineExpression2()", testMultilineExpression2),
        ("testMultilineExpression3()", testMultilineExpression3),
        ("testMultilineExpression4()", testMultilineExpression4),
        ("testMultilineExpression5()", testMultilineExpression5),
        ("testMultilineExpression6()", testMultilineExpression6),
        ("testTryExpression()", testTryExpression),
        ("testNilLiteral()", testNilLiteral),
        ("testTernaryConditionalOperator()", testTernaryConditionalOperator),
        ("testArrayLiteralExpression()", testArrayLiteralExpression),
        ("testDictionaryLiteralExpression()", testDictionaryLiteralExpression),
//        ("testMagicLiteralExpression()", testMagicLiteralExpression),
        ("testSelfExpression()", testSelfExpression),
//        ("testImplicitMemberExpression()", testImplicitMemberExpression),
        ("testTupleExpression()", testTupleExpression),
        ("testKeyPathExpression()", testKeyPathExpression),
        ("testSubscriptKeyPathExpression()", testSubscriptKeyPathExpression),
//        ("testInitializerExpression()", testInitializerExpression),
        ("testPostfixSelfExpression()", testPostfixSelfExpression),
        ("testForcedValueExpression()", testForcedValueExpression),
        ("testOptionalChainingExpression()", testOptionalChainingExpression),
        ("testNonAsciiCharacters()", testNonAsciiCharacters),
        ("testConditionalCompilationBlock()", testConditionalCompilationBlock),
//        ("testSelectorExpression()", testSelectorExpression),
        ("testExplicitMemberExpression()", testExplicitMemberExpression),
        ("testMultipleStatementInClosure()", testMultipleStatementInClosure),
        ("testMessageParameters()", testMessageParameters),
        ("testStringContainsNewlines()", testStringContainsNewlines),
        ("testStringContainsEscapeSequences()", testStringContainsEscapeSequences),
        ("testMultilineStringLiterals()", testMultilineStringLiterals),
        ("testCustomOperator()", testCustomOperator),
        ("testNoWhitespaces()", testNoWhitespaces),
        ("testHigerOrderFunction()", testHigerOrderFunction),
    ]
}

extension ParserTests {
    static var allTests: [(String, (ParserTests) -> () throws -> Void)] = [
        ("testParser()", testParser),
    ]
}

extension SourceFormatterTests {
    static var allTests: [(String, (SourceFormatterTests) -> () throws -> Void)] = [
        ("testSourceTokenizer()", testSourceTokenizer),
    ]
}

extension UtilityTests {
    static var allTests: [(String, (UtilityTests) -> () throws -> Void)] = [
        ("testDisplayWidth()", testDisplayWidth),
    ]
}

extension XCTAssertTests {
    static var allTests: [(String, (XCTAssertTests) -> () throws -> Void)] = [
        ("testBooleanAssertions()", testBooleanAssertions),
        ("testEqualityAssertions()", testEqualityAssertions),
        ("testComparableAssertions()", testComparableAssertions),
        ("testNilAssertions()", testNilAssertions),
        ("testExtraParameters()", testExtraParameters),
        ("testRawRepresentableString()", testRawRepresentableString),
        ("testRawRepresentableNumber()", testRawRepresentableNumber),
        ("testNoOutputWhenSucceeded()", testNoOutputWhenSucceeded),
        ("testThrowsFunction()", testThrowsFunction),
        ("testFunctionsInExtension()", testFunctionsInExtension),
        ("testStringInterpolation()", testStringInterpolation),
        ("testArrayEquatable()", testArrayEquatable),
//        ("testDoStatement()", testDoStatement),
        ("testTryAssert1()", testTryAssert1),
        ("testTryAssert2()", testTryAssert2),
        ("testRemovingUnexpectedLValueInType()", testRemovingUnexpectedLValueInType),
        ("testOptionalChaining1()", testOptionalChaining1),
        ("testOptionalChaining2()", testOptionalChaining2),
        ("testBinaryExpression()", testBinaryExpression),
//        ("testDictionaryLiteral()", testDictionaryLiteral),
        ("testAssertInClosure()", testAssertInClosure),
        ("testNoWhitespaces()", testNoWhitespaces),
        ("testCallExpression()", testCallExpression),
        ("testFunctionInArrayLiteral()", testFunctionInArrayLiteral),
        ("testMethodChaining()", testMethodChaining),
        ("testCustomNilCoalescingOperator()", testCustomNilCoalescingOperator),
    ]
}

XCTMain([
    testCase(AssertTests.allTests),
    testCase(ParserTests.allTests),
    testCase(SourceFormatterTests.allTests),
    testCase(UtilityTests.allTests),
    testCase(XCTAssertTests.allTests),
])
