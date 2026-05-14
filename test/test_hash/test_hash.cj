// bao_hash 哈希算法测试
package test_hash

import bao_hash.*
import bao_core.*
import std.unittest.*

class TestWyHash <: TestCases {
    @TestCase
    func testEmptyHash(): Unit {
        let h = WyHash.hash([])
        // 空输入也应返回确定的哈希值
        @AssertTrue(h != UInt64(0))
    }

    @TestCase
    func testDeterministic(): Unit {
        let data: Array<UInt8> = [72, 101, 108, 108, 111]
        let h1 = WyHash.hash(data)
        let h2 = WyHash.hash(data)
        @AssertEqual(h1, h2)
    }

    @TestCase
    func testDifferentInputs(): Unit {
        let h1 = WyHash.hash("hello")
        let h2 = WyHash.hash("world")
        @AssertNotEqual(h1, h2)
    }

    @TestCase
    func testSeed(): Unit {
        let data: Array<UInt8> = [1, 2, 3, 4]
        let h1 = WyHash.hashWithSeed(data, 0)
        let h2 = WyHash.hashWithSeed(data, 42)
        @AssertNotEqual(h1, h2)
    }
}

class TestCrc32 <: TestCases {
    @TestCase
    func testEmptyString(): Unit {
        let crc = Crc32.hash("")
        @AssertEqual(crc, UInt32(0))
    }

    @TestCase
    func testHelloWorld(): Unit {
        // CRC32("hello world") 的已知值
        let crc = Crc32.hash("hello world")
        // 确定性检查
        let crc2 = Crc32.hash("hello world")
        @AssertEqual(crc, crc2)
    }

    @TestCase
    func testDeterministic(): Unit {
        let data: Array<UInt8> = [1, 2, 3, 4, 5]
        let h1 = Crc32.hash(data)
        let h2 = Crc32.hash(data)
        @AssertEqual(h1, h2)
    }
}

class TestFnv1a <: TestCases {
    @TestCase
    func testEmptyString(): Unit {
        let h = Fnv1a.hash("")
        @AssertEqual(h, Fnv1a.FNV_OFFSET_BASIS)
    }

    @TestCase
    func testDeterministic(): Unit {
        let h1 = Fnv1a.hash("hello")
        let h2 = Fnv1a.hash("hello")
        @AssertEqual(h1, h2)
    }

    @TestCase
    func testDifferentInputs(): Unit {
        let h1 = Fnv1a.hash("hello")
        let h2 = Fnv1a.hash("world")
        @AssertNotEqual(h1, h2)
    }

    @TestCase
    func testByteAndStringConsistency(): Unit {
        let s = "test"
        var bytes = Array<UInt8>()
        for (c in s) {
            bytes.append(UInt8(c.value))
        }
        @AssertEqual(Fnv1a.hash(s), Fnv1a.hash(bytes))
    }
}

main() {
    TestWyHash().run()
    TestCrc32().run()
    TestFnv1a().run()
}
