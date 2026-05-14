// bao_core 字符串测试
package test_core

import bao_core.*
import std.unittest.*

class TestBaoString <: TestCases {
    @TestCase
    func testCreate(): Unit {
        let s = BaoString("hello")
        @AssertFalse(s.isEmpty())
        @AssertEqual(s.byteLength(), 5)
    }

    @TestCase
    func testEmpty(): Unit {
        let s = BaoString()
        @AssertTrue(s.isEmpty())
        @AssertEqual(s.byteLength(), 0)
    }

    @TestCase
    func testEquals(): Unit {
        let a = BaoString("hello")
        let b = BaoString("hello")
        let c = BaoString("world")
        @AssertTrue(a.equals(b))
        @AssertFalse(a.equals(c))
    }

    @TestCase
    func testConcat(): Unit {
        let a = BaoString("hello")
        let b = BaoString(" world")
        let c = a.concat(b)
        @AssertEqual(c.toString(), "hello world")
    }

    @TestCase
    func testSlice(): Unit {
        let s = BaoString("hello world")
        let sub = s.slice(0, 5)
        @AssertEqual(sub.toString(), "hello")
    }

    @TestCase
    func testClone(): Unit {
        let a = BaoString("test")
        let b = a.clone()
        @AssertTrue(a.equals(b))
    }
}

class TestBaoStringBuilder <: TestCases {
    @TestCase
    func testBuild(): Unit {
        let sb = BaoStringBuilder()
        sb.append("hello")
        sb.append(" ")
        sb.append("world")
        let result = sb.build()
        @AssertEqual(result.toString(), "hello world")
    }

    @TestCase
    func testAppendByte(): Unit {
        let sb = BaoStringBuilder()
        sb.appendByte(65)
        sb.appendByte(66)
        sb.appendByte(67)
        @AssertEqual(sb.build().toString(), "ABC")
    }

    @TestCase
    func testNewline(): Unit {
        let sb = BaoStringBuilder()
        sb.append("line1")
        sb.newline()
        sb.append("line2")
        @AssertEqual(sb.build().toString(), "line1\nline2")
    }

    @TestCase
    func testClear(): Unit {
        let sb = BaoStringBuilder()
        sb.append("test")
        sb.clear()
        @AssertTrue(sb.isEmpty())
    }
}

class TestHashedString <: TestCases {
    @TestCase
    func testHashConsistency(): Unit {
        let a = HashedString("hello")
        let b = HashedString("hello")
        @AssertEqual(a.hash, b.hash)
    }

    @TestCase
    func testHashDifferent(): Unit {
        let a = HashedString("hello")
        let b = HashedString("world")
        @AssertNotEqual(a.hash, b.hash)
    }

    @TestCase
    func testEquals(): Unit {
        let a = HashedString("test")
        let b = HashedString("test")
        let c = HashedString("other")
        @AssertTrue(a.equals(b))
        @AssertFalse(a.equals(c))
    }
}

main() {
    TestBaoString().run()
    TestBaoStringBuilder().run()
    TestHashedString().run()
}
