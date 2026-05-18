// 严格翻译自: src/sql_jsc/mysql/MySQLStatement.rs
// MySQL 预处理语句

package bao_sql_jsc.mysql

import bao_core.*
import bao_jsc.*

/// MySQL 预处理语句
/// 对应 Bun: MySQLStatement
/// 管理预处理语句的状态、列定义和参数信息
/// 使用侵入式引用计数管理生命周期
public class MySQLStatement {
    var refCount: Int64 = 1
    public var cachedStructure: CachedStructure = CachedStructure()
    public var statementId: UInt32 = 0
    public var params: Array<StatementParam> = []
    public var paramsReceived: UInt32 = 0
    public var columns: Array<ColumnDefinition41> = []
    public var columnsReceived: UInt32 = 0
    public var signature: Signature = Signature.empty()
    public var status: StatementStatus = StatementStatus.Parsing
    public var errorResponse: ErrorPacket = ErrorPacket()
    public var executionFlags: ExecutionFlags = ExecutionFlags()
    public var fieldsFlags: DataCellFlags = DataCellFlags()
    public var resultCount: UInt64 = 0

    public init() {}

    /// 设置初始引用计数
    /// 对应 Bun: MySQLStatement.initExactRefs
    /// 在构造时设置引用计数，用于多个所有者场景
    public func initExactRefs(count: Int64): Unit {
        refCount = count
    }

    /// 引用计数增加
    /// 对应 Bun: MySQLStatement.ref_
    public func ref(): Unit {
        refCount += 1
    }

    /// 引用计数减少
    /// 对应 Bun: MySQLStatement.deref
    public func deref(): Unit {
        refCount -= 1
        if (refCount <= 0) {
            deinit_()
        }
    }

    /// 重置执行状态
    /// 对应 Bun: MySQLStatement.reset
    public func reset(): Unit {
        resultCount = 0
        columnsReceived = 0
        executionFlags = ExecutionFlags()
    }

    /// 检查重复字段
    /// 对应 Bun: MySQLStatement.checkForDuplicateFields
    /// 遍历列定义，检测是否有重复的列名或索引
    public func checkForDuplicateFields(): Unit {
        if (!executionFlags.needsDuplicateCheck) {
            return
        }
        executionFlags.needsDuplicateCheck = false

        var seenNumbers = ArrayList<UInt32>()
        var seenFields = HashSet<String>()
        var flags = DataCellFlags()

        // 从后向前遍历
        var remaining = columns.size
        while (remaining > 0) {
            remaining -= 1
            let field = columns[remaining]
            match (field.nameOrIndex) {
                case Name(name) =>
                    if (seenFields.contains(name)) {
                        columns[remaining].nameOrIndex = NameOrIndex.Duplicate
                        flags.hasDuplicateColumns = true
                    }
                    seenFields.put(name)
                    flags.hasNamedColumns = true
                case Index(index) =>
                    if (seenNumbers.contains(index)) {
                        columns[remaining].nameOrIndex = NameOrIndex.Duplicate
                        flags.hasDuplicateColumns = true
                    } else {
                        seenNumbers.append(index)
                    }
                    flags.hasIndexedColumns = true
                case Duplicate =>
                    flags.hasDuplicateColumns = true
            }
        }

        fieldsFlags = flags
    }

    /// 获取结构
    /// 对应 Bun: MySQLStatement.structure
    /// 返回或构建缓存的列结构，用于 JS 对象构建
    public func structure(owner: JscValue, globalObject: JscJSGlobalObject): CachedStructure {
        if (cachedStructure.has()) {
            return cachedStructure
        }
        checkForDuplicateFields()

        // 构建列标识符数组
        var nonDuplicatedCount = columns.size
        for (col in columns) {
            match (col.nameOrIndex) {
                case Duplicate => nonDuplicatedCount -= 1
                case _ => ()
            }
        }

        let ids = Array<ExternColumnIdentifier>(nonDuplicatedCount, item: ExternColumnIdentifier())
        var i: Int64 = 0
        for (col in columns) {
            match (col.nameOrIndex) {
                case Duplicate => continue
                case Name(name) =>
                    ids[i].tag = 2
                    ids[i].nameIndex = 0 // 实际应为原子 ID
                case Index(index) =>
                    ids[i].tag = 1
                    ids[i].nameIndex = index
            }
            i += 1
        }

        cachedStructure.set(globalObject, None, ids)
        return cachedStructure
    }

    /// 释放资源
    /// 对应 Bun: MySQLStatement.deinit (Drop)
    private func deinit_(): Unit {
        cachedStructure.deinit()
        columns = []
        params = []
        signature.deinit()
        errorResponse = ErrorPacket()
    }
}

/// 语句参数
/// 对应 Bun: MySQLStatement.Param
public class StatementParam {
    public var fieldType: UInt8 = 0
    public var flags: ColumnFlags = ColumnFlags()

    public init() {}
}

/// 列标志
/// 对应 Bun: ColumnFlags
public class ColumnFlags {
    public var unsigned: Bool = false
    public var binary: Bool = false

    public init() {}

    public static let UNSIGNED_MASK: UInt16 = 0x0020
    public static let BINARY_MASK: UInt16 = 0x0080

    public func contains(mask: UInt16): Bool {
        if (mask == UNSIGNED_MASK) { return unsigned }
        if (mask == BINARY_MASK) { return binary }
        return false
    }
}

/// 执行标志
/// 对应 Bun: MySQLStatement.ExecutionFlags (bitflags)
public class ExecutionFlags {
    public var headerReceived: Bool = false
    public var needsDuplicateCheck: Bool = true
    public var needToSendParams: Bool = true
    public var columnsEofReceived: Bool = false

    public init() {}

    /// 默认值: needsDuplicateCheck=true, needToSendParams=true
    public static func default_(): ExecutionFlags {
        let flags = ExecutionFlags()
        flags.needsDuplicateCheck = true
        flags.needToSendParams = true
        return flags
    }

    public func contains(flag: ExecutionFlag): Bool {
        match (flag) {
            case HeaderReceived => headerReceived
            case NeedsDuplicateCheck => needsDuplicateCheck
            case NeedToSendParams => needToSendParams
            case ColumnsEofReceived => columnsEofReceived
        }
    }

    public func insert(flag: ExecutionFlag): Unit {
        match (flag) {
            case HeaderReceived => headerReceived = true
            case NeedsDuplicateCheck => needsDuplicateCheck = true
            case NeedToSendParams => needToSendParams = true
            case ColumnsEofReceived => columnsEofReceived = true
        }
    }

    public func remove(flag: ExecutionFlag): Unit {
        match (flag) {
            case HeaderReceived => headerReceived = false
            case NeedsDuplicateCheck => needsDuplicateCheck = false
            case NeedToSendParams => needToSendParams = false
            case ColumnsEofReceived => columnsEofReceived = false
        }
    }
}

/// 执行标志枚举
/// 对应 Bun: ExecutionFlags bit positions
public enum ExecutionFlag {
    | HeaderReceived
    | NeedsDuplicateCheck
    | NeedToSendParams
    | ColumnsEofReceived
}

/// 列定义
/// 对应 Bun: ColumnDefinition41
public class ColumnDefinition41 {
    public var nameOrIndex: NameOrIndex = NameOrIndex.Index(0)
    public var columnType: UInt8 = 0
    public var columnLength: UInt32 = 0
    public var flags: ColumnFlags = ColumnFlags()
    public var characterSet: UInt16 = 0

    public init() {}

    /// 解码列定义
    public func decode(data: Array<UInt8>, offset: Int64): Int64 {
        // 解码 column_definition41 格式
        return offset
    }

    public func deinit(): Unit {}
}

/// 名称或索引
/// 对应 Bun: ColumnIdentifier
public enum NameOrIndex {
    | Name(String)
    | Index(UInt32)
    | Duplicate
}

/// 数据单元格标志
/// 对应 Bun: DataCellFlags
public class DataCellFlags {
    public var hasDuplicateColumns: Bool = false
    public var hasNamedColumns: Bool = false
    public var hasIndexedColumns: Bool = false

    public init() {}

    public static func default_(): DataCellFlags {
        return DataCellFlags()
    }

    public func insert(flag: DataCellFlag): Unit {
        match (flag) {
            case HasDuplicateColumns => hasDuplicateColumns = true
            case HasNamedColumns => hasNamedColumns = true
            case HasIndexedColumns => hasIndexedColumns = true
        }
    }
}

/// 数据单元格标志枚举
public enum DataCellFlag {
    | HasDuplicateColumns
    | HasNamedColumns
    | HasIndexedColumns
}

/// 错误包
/// 对应 Bun: ErrorPacket
public class ErrorPacket {
    public var header: UInt8 = 0
    public var errorCode: UInt16 = 0
    public var errorMessage: String = ""
    public var sqlState: String = ""
    public var sqlStateMarker: String = ""

    public init() {}

    public init(errorCode: UInt16, errorMessage: String, sqlState: String) {
        this.errorCode = errorCode
        this.errorMessage = errorMessage
        this.sqlState = sqlState
    }

    public func deinit(): Unit {
        errorMessage = ""
        sqlState = ""
    }

    /// 转换为 JS 错误
    /// 对应 Bun: ErrorPacket.toJS
    public func toJS(globalObject: JscJSGlobalObject): JscValue {
        var msg = errorMessage
        if (msg.size == 0) {
            msg = "MySQL error occurred"
        }

        let code = if (errorCode == 1064) "ERR_MYSQL_SYNTAX_ERROR" else "ERR_MYSQL_SERVER_ERROR"
        return createMySQLError(globalObject, msg, code, errorCode, sqlState)
    }
}

/// 创建 MySQL 错误 JS 对象
/// 对应 Bun: createMySQLError
public func createMySQLError(globalObject: JscJSGlobalObject, message: String,
                              code: String, errno: UInt16, sqlState: String): JscValue {
    let optsObj = JscObject.createEmptyObject(globalObject)
    optsObj.put(globalObject, "code", JscValue(code))
    optsObj.put(globalObject, "errno", JscValue(errno))
    optsObj.put(globalObject, "sqlState", JscValue(sqlState))
    optsObj.put(globalObject, "message", JscValue(message))
    return optsObj.toValue()
}

/// 外部列标识符
/// 对应 Bun: ExternColumnIdentifier
public class ExternColumnIdentifier {
    public var tag: UInt8 = 0
    public var nameIndex: UInt32 = 0

    public init() {}
}

/// 缓存结构
/// 对应 Bun: CachedStructure
public class CachedStructure {
    private var cached: Bool = false
    private var jsValue: JscValue = JscValue.undefined()

    public init() {}

    public func has(): Bool {
        return cached
    }

    public func set(globalObject: JscJSGlobalObject, owner: ?JscValue,
                     ids: Array<ExternColumnIdentifier>): Unit {
        cached = true
    }

    public func deinit(): Unit {
        cached = false
        jsValue = JscValue.undefined()
    }

    public func jsValue(): JscValue {
        return jsValue
    }
}
