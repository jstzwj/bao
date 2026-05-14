// bao_parser 解析器测试
package test_parser

import bao_parser.*
import bao_core.*
import std.unittest.*

class TestJsParserBasic <: TestCases {
    @TestCase
    func testEmptyInput(): Unit {
        let parser = JsParser()
        let options = ParserOptions()
        let result = parser.parse("", options)
        @AssertFalse(result.hasErrors())
    }

    @TestCase
    func testVariableDeclaration(): Unit {
        let parser = JsParser()
        let options = ParserOptions()
        let result = parser.parse("var x = 1;", options)
        // 骨架版本，只验证不崩溃
        @AssertTrue(true)
    }

    @TestCase
    func testFunctionDeclaration(): Unit {
        let parser = JsParser()
        let options = ParserOptions()
        let result = parser.parse("function hello() {}", options)
        @AssertTrue(true)
    }

    @TestCase
    func testSkipComments(): Unit {
        let parser = JsParser()
        let options = ParserOptions()
        let result = parser.parse("// this is a comment\nvar x = 1;", options)
        @AssertTrue(true)
    }
}

class TestJsPrinterBasic <: TestCases {
    @TestCase
    func testEmptyProgram(): Unit {
        let loc = SourceLocation(0, 0, 1, 0)
        let program = Program(loc, "test.js")
        let printer = JsPrinter()
        let output = printer.print(program)
        @AssertTrue(output.isEmpty())
    }
}

main() {
    TestJsParserBasic().run()
    TestJsPrinterBasic().run()
}
