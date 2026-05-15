// 严格翻译自: src/sql_jsc/shared/CachedStructure.zig
// 缓存的 JS 结构体

package bao_sql_jsc

import bao_core.*
import bao_jsc.*

/// 缓存 JS 结构体
/// 对应 Bun: CachedStructure
public class CachedStructure {
    var structure: ?JscValue = None   // jsc.Strong.Optional
    var fields: ?Array<ExternColumnIdentifier> = None

    public init() {}

    public func has(): Bool {
        return structure != None || fields != None
    }

    public func jsValue(): ?JscValue {
        return structure
    }

    public func set(globalObject: JscJSGlobalObject, value: ?JscValue, fields: ?Array<ExternColumnIdentifier>): Unit {
        if (value != None) {
            structure = value
        }
        this.fields = fields
    }

    public func deinit(): Unit {
        structure = None
        fields = None
    }
}

/// 外部列标识符
/// 对应 Bun: jsc.JSObject.ExternColumnIdentifier
public class ExternColumnIdentifier {
    public var tag: UInt8 = 0
    public var nameIndex: UInt32 = 0  // 索引或名称原子 ID

    public init() {}

    public init(tag: UInt8, nameIndex: UInt32) {
        this.tag = tag
        this.nameIndex = nameIndex
    }

    public func deinit(): Unit {
        // 清理资源
    }
}
