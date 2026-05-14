// bao_core 单元测试
package test_core

import bao_core.*
import std.unittest.*

class TestTypes <: TestCases {
    @TestCase
    func testBaoVersion(): Unit {
        @AssertEqual(BAO_VERSION, "0.1.0")
    }

    @TestCase
    func testUserAgent(): Unit {
        @AssertTrue(USER_AGENT.contains("Bao"))
        @AssertTrue(USER_AGENT.contains("0.1.0"))
    }

    @TestCase
    func testMaxPathBytes(): Unit {
        @AssertEqual(MAX_PATH_BYTES, 4096)
    }
}

class TestBaoError <: TestCases {
    @TestCase
    func testBaoErrorCreation(): Unit {
        let err = BaoError(42, "test error")
        @AssertEqual(err.code, 42)
        @AssertEqual(err.message, "test error")
    }

    @TestCase
    func testOutOfMemoryError(): Unit {
        let err = OutOfMemoryError()
        @AssertEqual(err.code, 1)
    }

    @TestCase
    func testFileNotFoundError(): Unit {
        let err = FileNotFoundError("/tmp/nonexistent")
        @AssertEqual(err.code, 2)
        @AssertTrue(err.message.contains("nonexistent"))
    }

    @TestCase
    func testParseError(): Unit {
        let err = ParseError(10, 5, "unexpected token")
        @AssertEqual(err.line, 10)
        @AssertEqual(err.column, 5)
        @AssertTrue(err.message.contains("10:5"))
    }
}

class TestPosixError <: TestCases {
    @TestCase
    func testErrorCodes(): Unit {
        @AssertEqual(PosixError.ENOENT, 2)
        @AssertEqual(PosixError.EACCES, 13)
        @AssertEqual(PosixError.EEXIST, 17)
        @AssertEqual(PosixError.ENOSPC, 28)
    }

    @TestCase
    func testErrorMessages(): Unit {
        @AssertEqual(PosixError.fromCode(2), "No such file or directory")
        @AssertEqual(PosixError.fromCode(13), "Permission denied")
        @AssertEqual(PosixError.fromCode(42), "Unknown error (42)")
    }
}

class TestByteBuffer <: TestCases {
    @TestCase
    func testWriteAndRead(): Unit {
        let buf = ByteBuffer(64)
        buf.writeByte(65)
        buf.writeByte(66)
        buf.writeByte(67)
        @AssertEqual(buf.position(), 3)

        buf.reset()
        @AssertEqual(buf.readByte(), 65)
        @AssertEqual(buf.readByte(), 66)
        @AssertEqual(buf.readByte(), 67)
    }

    @TestCase
    func testSlice(): Unit {
        let buf = ByteBuffer(64)
        buf.writeBytes([72, 101, 108, 108, 111])
        let slice = buf.slice()
        @AssertEqual(slice.size, 5)
        @AssertEqual(slice[0], 72)
    }

    @TestCase
    func testClear(): Unit {
        let buf = ByteBuffer(64)
        buf.writeByte(1)
        buf.clear()
        @AssertEqual(buf.position(), 0)
        @AssertEqual(buf.remaining(), 64)
    }
}

main() {
    TestTypes().run()
    TestBaoError().run()
    TestPosixError().run()
    TestByteBuffer().run()
}
