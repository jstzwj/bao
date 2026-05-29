// 严格翻译自: src/runtime/api/sql.classes.ts
package bao_runtime.api

import bao_jsc.{JsGlobalObject, JsValue}

// ============================================================================
// sql.classes.ts 类绑定定义
// Bun: PostgresSQL, MySQL 连接和查询的 JSC 绑定
// ============================================================================

// ============================================================================
// SQLConnection - SQL 数据库连接
// 严格翻译自: sql.classes.ts 中 PostgresSQLConnection / MySQLConnection
// construct: true, finalize: true, configurable: false
// values: ["onconnect", "onclose", "queries"]
// ============================================================================

/// SQLConnection JSC 绑定 (PostgresSQL / MySQL 共享接口)
public class SQLConnectionClasses {

    /// close fn
    /// 严格翻译自: proto.close { fn: "doClose" }
    public static func doClose(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// connected getter
    /// 严格翻译自: proto.connected { getter: "getConnected" }
    public static func getConnected(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        return JsValue.jsBoolean(false)
    }

    /// ref fn
    /// 严格翻译自: proto.ref { fn: "doRef" }
    public static func doRef(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// unref fn
    /// 严格翻译自: proto.unref { fn: "doUnref" }
    public static func doUnref(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// flush fn
    /// 严格翻译自: proto.flush { fn: "doFlush" }
    public static func doFlush(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// queries getter (`this`: true)
    /// 严格翻译自: proto.queries { getter: "getQueries", `this`: true }
    public static func getQueries(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// onconnect getter/setter (`this`: true)
    /// 严格翻译自: proto.onconnect { getter: "getOnConnect", setter: "setOnConnect", `this`: true }
    public static func getOnConnect(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// setOnConnect setter
    public static func setOnConnect(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// onclose getter/setter (`this`: true)
    /// 严格翻译自: proto.onclose { getter: "getOnClose", setter: "setOnClose", `this`: true }
    public static func getOnClose(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// setOnClose setter
    public static func setOnClose(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }
}

// ============================================================================
// SQLQuery - SQL 查询
// 严格翻译自: sql.classes.ts 中 PostgresSQLQuery / MySQLQuery
// construct: true, finalize: true, configurable: false
// values: ["pendingValue", "target", "columns", "binding"]
// estimatedSize: true
// ============================================================================

/// SQLQuery JSC 绑定 (PostgresSQL / MySQL 共享接口)
public class SQLQueryClasses {

    /// run fn
    /// 严格翻译自: proto.run { fn: "doRun", length: 2 }
    public static func doRun(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// cancel fn
    /// 严格翻译自: proto.cancel { fn: "doCancel", length: 0 }
    public static func doCancel(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// done fn
    /// 严格翻译自: proto.done { fn: "doDone", length: 0 }
    public static func doDone(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// setMode fn
    /// 严格翻译自: proto.setMode { fn: "setModeFromJS", length: 1 }
    public static func setModeFromJS(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// setPendingValue fn
    /// 严格翻译自: proto.setPendingValue { fn: "setPendingValueFromJS", length: 1 }
    public static func setPendingValueFromJS(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }
}
