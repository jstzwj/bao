package bao_cli

import bao_collections.*
import bao_http.*

public class ByteArray {
    public var data: Array<UInt8>

    public init() {
        data = []
    }

    public init(data: Array<UInt8>) {
        this.data = data
    }
}

public class JsonObject {
    private var entries: ArrayList<Entry>

    public init() {
        entries = ArrayList<Entry>()
    }

    public func setString(key: String, value: String): Unit {
        entries.append(Entry(key, "\"${value}\""))
    }

    public func setBool(key: String, value: Bool): Unit {
        entries.append(Entry(key, "${value}"))
    }

    public func setObject(key: String, obj: JsonObject): Unit {
        entries.append(Entry(key, obj.serialize()))
    }

    public func setNumber(key: String, value: Int64): Unit {
        entries.append(Entry(key, "${value}"))
    }

    public func serialize(): String {
        var result = "{"
        var first = true
        for (e in entries) {
            if (!first) {
                result = result + ","
            }
            first = false
            result = result + "\"${e.key}\": ${e.val}"
        }
        result = result + "}"
        return result
    }
}

public class Entry {
    public var key: String
    public var val: String
    public init(key: String, val: String) {
        this.key = key
        this.val = val
    }
}

public class VirtualMachine {
    public init() {}

    // 覆盖率字节范围 (桩)
    public func getCoverageByteRanges(): ArrayList<Any> {
        ArrayList<Any>()
    }

    // 顶级目录 (桩)
    public func getTopLevelDir(): String {
        ""
    }
}

public class JSValue {
    public static func jsUndefined(): JSValue {
        return JSValue()
    }

    public init() {}
}

public class PackageJsonAst {
    public init() {}
}

public enum JsonExpr {
    | Null
    | `Bool`(Bool)
    | Int(Int64)
    | Float(Float64)
    | Str(String)
    | `Array`(ArrayList<JsonExpr>)
    | `Object`(ArrayList<Tuple<String, JsonExpr>>)

    public func asProperty(key: String): JsonExpr {
        return JsonExpr.Null
    }

    public func toString(): String {
        return ""
    }
}

public class SemverParsedVersion {
    public init() {}
}

public class DependentInfo {
    public var name: String
    public var version: String
    public init() {
        name = ""
        version = ""
    }
}

public enum DependencyType {
    | Production
    | Dev
    | Optional
    | Peer
}