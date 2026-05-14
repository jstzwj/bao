// bao_collections 集合测试
package test_collections

import bao_collections.*
import bao_core.*
import std.unittest.*

class TestStringMap <: TestCases {
    @TestCase
    func testPutAndGet(): Unit {
        let m = StringMap<String>()
        m.put("key", "value")
        @AssertEqual(m.get("key"), Some("value"))
    }

    @TestCase
    func testGetMissing(): Unit {
        let m = StringMap<String>()
        @AssertEqual(m.get("missing"), None)
    }

    @TestCase
    func testContains(): Unit {
        let m = StringMap<Int64>()
        m.put("one", 1)
        @AssertTrue(m.contains("one"))
        @AssertFalse(m.contains("two"))
    }

    @TestCase
    func testRemove(): Unit {
        let m = StringMap<String>()
        m.put("key", "value")
        m.remove("key")
        @AssertFalse(m.contains("key"))
        @AssertEqual(m.size(), 0)
    }

    @TestCase
    func testSize(): Unit {
        let m = StringMap<String>()
        @AssertEqual(m.size(), 0)
        m.put("a", "1")
        m.put("b", "2")
        @AssertEqual(m.size(), 2)
    }

    @TestCase
    func testClear(): Unit {
        let m = StringMap<String>()
        m.put("a", "1")
        m.clear()
        @AssertTrue(m.isEmpty())
    }
}

class TestStringSet <: TestCases {
    @TestCase
    func testInsert(): Unit {
        let s = StringSet()
        @AssertTrue(s.insert("hello"))
        @AssertFalse(s.insert("hello"))  // 重复
    }

    @TestCase
    func testContains(): Unit {
        let s = StringSet()
        s.insert("test")
        @AssertTrue(s.contains("test"))
        @AssertFalse(s.contains("other"))
    }

    @TestCase
    func testRemove(): Unit {
        let s = StringSet()
        s.insert("test")
        @AssertTrue(s.remove("test"))
        @AssertFalse(s.contains("test"))
    }

    @TestCase
    func testSize(): Unit {
        let s = StringSet()
        @AssertEqual(s.size(), 0)
        s.insert("a")
        s.insert("b")
        @AssertEqual(s.size(), 2)
    }
}

class TestArrayBuffer <: TestCases {
    @TestCase
    func testAppend(): Unit {
        let buf = ArrayBuffer()
        buf.append(72)
        buf.append(101)
        buf.append(108)
        @AssertEqual(buf.len(), 3)
    }

    @TestCase
    func testAppendString(): Unit {
        let buf = ArrayBuffer()
        buf.appendString("abc")
        let slice = buf.slice()
        @AssertEqual(slice.size, 3)
        @AssertEqual(slice[0], UInt8('a'))
    }

    @TestCase
    func testClear(): Unit {
        let buf = ArrayBuffer()
        buf.appendString("test")
        buf.clear()
        @AssertEqual(buf.len(), 0)
    }

    @TestCase
    func testAutoGrow(): Unit {
        let buf = ArrayBuffer(4)  // 小初始容量
        for (i in 0..100) {
            buf.append(UInt8(i % 256))
        }
        @AssertEqual(buf.len(), 100)
    }
}

main() {
    TestStringMap().run()
    TestStringSet().run()
    TestArrayBuffer().run()
}
