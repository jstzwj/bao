// MySQL JS 预编译语句绑定
// 严格翻译自: src/sql_jsc/mysql/MySQLStatement.zig
//
// 预编译语句的 JS 层状态管理，负责:
// - 参数和列定义的累积
// - 缓存 JS 对象结构 (CachedStructure)
// - 重复列检测
// - 语句生命周期
package bao_runtime.sql.mysql

import bao_core.*
import bao_runtime.sql.shared.*

/// MySQL 预编译语句的 JS 扩展
/// 对应 Bun: MySQLStatement (JSC 部分)
/// 包含 JS 缓存结构、执行标志和重复列检测
public class MySQLStatementJSC {
    /// 缓存结构
    public var cachedStructure: CachedStructure
    /// 引用计数
    public var refCount: Int64
    /// 语句 ID
    public var statementId: UInt32
    /// 参数描述
    public var params: ArrayList<MySQLParam>
    /// 已接收参数数
    public var paramsReceived: UInt32
    /// 列定义
    public var columns: ArrayList<ColumnDefinition41>
    /// 已接收列数
    public var columnsReceived: UInt32
    /// 签名 (用于预编译语句缓存)
    public var signature: Signature
    /// 状态
    public var status: StatementStatus
    /// 错误响应
    public var errorResponse: ErrorPacket
    /// 执行标志
    public var executionFlags: ExecutionFlags
    /// 字段标志
    public var fieldsFlags: SQLDataCellFlags
    /// 结果计数
    public var resultCount: UInt64

    public init() {
        cachedStructure = CachedStructure()
        refCount = 1
        statementId = 0
        params = ArrayList<MySQLParam>()
        paramsReceived = 0
        columns = ArrayList<ColumnDefinition41>()
        columnsReceived = 0
        signature = Signature.empty()
        status = StatementStatus.parsing
        errorResponse = ErrorPacket()
        executionFlags = ExecutionFlags()
        fieldsFlags = SQLDataCellFlags()
        resultCount = 0
    }

    // ============================================================================
    // 引用计数
    // ============================================================================

    /// 增加引用
    public func ref(): Unit {
        refCount += 1
    }

    /// 减少引用
    public func deref(): Unit {
        refCount -= 1
        if (refCount <= 0) {
            deinit()
        }
    }

    /// 释放资源
    /// 对应 Bun: MySQLStatement.deinit
    public func deinit(): Unit {
        for (col in columns) {
            col.deinit()
        }
        columns = ArrayList<ColumnDefinition41>()
        params = ArrayList<MySQLParam>()
        cachedStructure.deinit()
        signature.deinit()
    }

    /// 重置 (每次执行前)
    /// 对应 Bun: MySQLStatement.reset
    public func reset(): Unit {
        resultCount = 0
        columnsReceived = 0
        executionFlags = ExecutionFlags()
    }

    // ============================================================================
    // 重复列检测
    // 对应 Bun: MySQLStatement.checkForDuplicateFields
    // ============================================================================

    /// 检查重复字段
    public func checkForDuplicateFields(): Unit {
        if (!executionFlags.needsDuplicateCheck) {
            return
        }
        executionFlags.needsDuplicateCheck = false

        let seenNames = HashSet<String>()
        var seenNumbers = ArrayList<UInt32>()
        var flags = SQLDataCellFlags()

        // 从后向前迭代
        var remaining = columns.size
        while (remaining > 0) {
            remaining -= 1
            let field = columns[remaining]

            match (field.nameOrIndex.idType) {
                case ColumnIdentifier.IdType.name =>
                    let nameStr = field.nameOrIndex.name.slice()
                    var nameKey = ""
                    for (b in nameStr) {
                        nameKey += String(Char(b))
                    }
                    if (seenNames.contains(nameKey)) {
                        field.nameOrIndex.idType = ColumnIdentifier.IdType.duplicate
                        flags.hasDuplicateColumns = true
                    } else {
                        seenNames.put(nameKey)
                    }
                    flags.hasNamedColumns = true
                case ColumnIdentifier.IdType.index =>
                    let index = field.nameOrIndex.index
                    if (seenNumbers.contains(index)) {
                        field.nameOrIndex.idType = ColumnIdentifier.IdType.duplicate
                        flags.hasDuplicateColumns = true
                    } else {
                        seenNumbers.append(index)
                    }
                    flags.hasIndexedColumns = true
                case ColumnIdentifier.IdType.duplicate =>
                    flags.hasDuplicateColumns = true
            }
        }

        fieldsFlags = flags
    }

    /// 获取/创建缓存结构
    /// 对应 Bun: MySQLStatement.structure
    public func structure(owner: JSValueRef, globalObject: JSValueRef): CachedStructure {
        if (cachedStructure.has()) {
            return cachedStructure
        }
        checkForDuplicateFields()

        // 计算非重复列数
        var nonDuplicatedCount = columns.size
        for (col in columns) {
            if (col.nameOrIndex.idType == ColumnIdentifier.IdType.duplicate) {
                nonDuplicatedCount -= 1
            }
        }

        let ids = ArrayList<ExternColumnIdentifier>()
        for (col in columns) {
            if (col.nameOrIndex.idType == ColumnIdentifier.IdType.duplicate) {
                continue
            }

            let id = ExternColumnIdentifier()
            match (col.nameOrIndex.idType) {
                case ColumnIdentifier.IdType.name =>
                    let nameSlice = col.nameOrIndex.name.slice()
                    var nameStr = ""
                    for (b in nameSlice) {
                        nameStr += String(Char(b))
                    }
                    id.name = nameStr
                    id.tag = 2
                case ColumnIdentifier.IdType.index =>
                    id.index = col.nameOrIndex.index
                    id.tag = 1
                case ColumnIdentifier.IdType.duplicate =>
                    id.tag = 0
            }
            ids.append(id)
        }

        cachedStructure.set(globalObject, None, ids)
        return cachedStructure
    }

    /// 将 columns 转为 ArrayList<ColumnDefinition41> (与协议层兼容)
    public func columnsAsArrayList(): ArrayList<ColumnDefinition41> {
        return columns
    }
}

/// 执行标志
/// 对应 Bun: MySQLStatement.ExecutionFlags
public class ExecutionFlags {
    /// 是否已接收 header
    public var headerReceived: Bool
    /// 是否需要重复列检测
    public var needsDuplicateCheck: Bool
    /// 是否需要发送参数类型
    public var needToSendParams: Bool
    /// 是否已接收 columns EOF (legacy protocol)
    public var columnsEofReceived: Bool

    public init() {
        headerReceived = false
        needsDuplicateCheck = true
        needToSendParams = true
        columnsEofReceived = false
    }
}

/// SQL 数据单元格标志
/// 对应 Bun: SQLDataCell.Flags
public class SQLDataCellFlags {
    public var hasIndexedColumns: Bool
    public var hasNamedColumns: Bool
    public var hasDuplicateColumns: Bool

    public init() {
        hasIndexedColumns = false
        hasNamedColumns = false
        hasDuplicateColumns = false
    }
}

/// 缓存结构
/// 对应 Bun: CachedStructure
public class CachedStructure {
    /// JS 结构值
    public var structureValue: JSValueRef
    /// 字段标识符 (当字段数超过内联容量时)
    public var fields: ?ArrayList<ExternColumnIdentifier>

    public init() {
        structureValue = JSValueRef()
        fields = None
    }

    /// 是否有缓存
    public func has(): Bool {
        return structureValue.isNotEmpty() || fields.isSome()
    }

    /// 获取 JS 值
    public func jsValue(): JSValueRef {
        return structureValue
    }

    /// 设置
    public func set(globalObject: JSValueRef, value: ?JSValueRef, ids: ArrayList<ExternColumnIdentifier>): Unit {
        if (let Some(v) <- value) {
            structureValue = v
        }
        fields = ids
    }

    /// 释放
    public func deinit(): Unit {
        structureValue = JSValueRef()
        if (let Some(f) <- fields) {
            fields = None
        }
    }
}

/// 外部列标识符
/// 对应 Bun: jsc.JSObject.ExternColumnIdentifier
public class ExternColumnIdentifier {
    /// 标签 (0=duplicate, 1=index, 2=name)
    public var tag: Int64
    /// 列名
    public var name: String
    /// 列索引
    public var index: UInt32

    public init() {
        tag = 0
        name = ""
        index = 0
    }

    public func deinit(): Unit {
        name = ""
    }
}

/// 签名
/// 对应 Bun: Signature (protocol/Signature.zig)
/// 用于预编译语句缓存键
public class Signature {
    /// 参数字段列表
    public var fields: ArrayList<MySQLParam>
    /// 签名名称 (查询 + 参数类型名)
    public var name: String
    /// 查询文本
    public var query: String

    public init() {
        fields = ArrayList<MySQLParam>()
        name = ""
        query = ""
    }

    /// 创建空签名
    public static func empty(): Signature {
        return Signature()
    }

    /// 释放
    public func deinit(): Unit {
        fields = ArrayList<MySQLParam>()
        name = ""
        query = ""
    }

    /// 计算哈希
    public func hash(): UInt64 {
        // 简化实现
        var h: UInt64 = 0
        for (c in name) {
            h = h * 31 + UInt64(c.toUInt8())
        }
        return h
    }

    /// 从 JS 值生成签名
    /// 对应 Bun: Signature.generate
    public static func generate(
        globalObject: JSValueRef,
        query: String,
        arrayValue: JSValueRef,
        columnsValue: JSValueRef
    ): Signature {
        let sig = Signature()
        sig.query = query
        sig.name = query

        // 在真实环境中遍历 JS 数组，推断每个参数的类型
        // 将类型名追加到 name 以形成唯一签名

        return sig
    }
}
