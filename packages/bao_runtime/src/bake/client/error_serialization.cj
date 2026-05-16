// 翻译自 Bun: src/runtime/bake/client/error-serialization.ts
// WebSocket 协议中的 bundler 错误反序列化。

package bao_runtime.bake.client

import bao_runtime.bake.*

public class DeserializedFailure {
    /// 未指定时代表客户端错误。
    public var file: ?String
    public var messages: Array<BundlerMessage>

    public init(file: ?String, messages: Array<BundlerMessage>) {
        this.file = file
        this.messages = messages
    }
}

public class BundlerMessage {
    public let kind: String = "bundler"
    public var level: BundlerMessageLevel
    public var message: String
    public var location: ?BundlerMessageLocation
    public var notes: Array<BundlerNote>

    public init(level: BundlerMessageLevel, message: String, location: ?BundlerMessageLocation, notes: Array<BundlerNote>) {
        this.level = level
        this.message = message
        this.location = location
        this.notes = notes
    }
}

public class BundlerMessageLocation {
    /// 一基行号。
    public var line: UInt32
    /// 一基列号。
    public var column: UInt32
    /// 字节长度。
    public var length: UInt32
    public var lineText: String

    public init(line: UInt32, column: UInt32, length: UInt32, lineText: String) {
        this.line = line
        this.column = column
        this.length = length
        this.lineText = lineText
    }
}

public class BundlerNote {
    public var message: String
    public var location: ?BundlerMessageLocation

    public init(message: String, location: ?BundlerMessageLocation) {
        this.message = message
        this.location = location
    }
}

public func decodeSerializedError(reader: DataViewReader): BundlerMessage {
    let kind = reader.u8()
    if (kind >= 0 && kind <= 4) {
        return readLogMsg(reader, BundlerMessageLevel.fromByte(kind))
    }
    throw Error("TODO: JS Errors")
}

/// 第一个字节已由调用方读取。
func readLogMsg(r: DataViewReader, level: BundlerMessageLevel): BundlerMessage {
    let message = r.string32()
    let location = readBundlerMessageLocationOrNull(r)
    let noteCount = r.u32()
    var notes = Array<BundlerNote>()
    for (i in 0..noteCount) {
        notes.append(readLogData(r))
    }
    return BundlerMessage(level, message, location, notes)
}

func readLogData(r: DataViewReader): BundlerNote {
    return BundlerNote(r.string32(), readBundlerMessageLocationOrNull(r))
}

func readBundlerMessageLocationOrNull(r: DataViewReader): ?BundlerMessageLocation {
    let line = r.u32()
    if (line == 0) { return None }
    let column = r.u32()
    let length = r.u32()
    let lineText = r.string32()
    return Some(BundlerMessageLocation(line, column, length, lineText))
}

public enum BundlerMessageLevel {
    | err
    | warn
    | note
    | debug
    | verbose

    public static func fromByte(value: UInt8): BundlerMessageLevel {
        match (value) {
            case 0 => err
            case 1 => warn
            case 2 => note
            case 3 => debug
            case _ => verbose
        }
    }
}
