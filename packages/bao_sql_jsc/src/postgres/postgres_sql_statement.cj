// 严格翻译自: src/sql_jsc/postgres/PostgresSQLStatement.zig
// Postgres SQL 预处理语句

package bao_sql_jsc

import bao_core.*
import bao_jsc.*

/// Postgres SQL 预处理语句
/// 对应 Bun: PostgresSQLStatement
/// 管理 PostgreSQL 预处理语句的状态、字段定义和参数
public class PostgresSQLStatement {
    var refCount: Int64 = 1
    public var cachedStructure: CachedStructure = CachedStructure()
    public var fields: Array<FieldDescription> = []
    public var parameters: Array<Int32> = []
    public var signature: PostgresSignature = PostgresSignature.empty()
    public var status: PostgresStatementStatus = PostgresStatementStatus.Pending
    public var errorResponse: ?PostgresStatementError = None
    public var needsDuplicateCheck: Bool = true
    public var fieldsFlags: DataCellFlags = DataCellFlags()

    public init() {}

    /// 引用计数增加
    public func ref(): Unit {
        refCount += 1
    }

    /// 引用计数减少
    public func deref(): Unit {
        refCount -= 1
        if (refCount <= 0) {
            deinit_()
        }
    }

    /// 检查重复字段
    /// 对应 Bun: PostgresSQLStatement.checkForDuplicateFields
    public func checkForDuplicateFields(): Unit {
        if (!needsDuplicateCheck) {
            return
        }
        needsDuplicateCheck = false

        var seenNumbers = ArrayList<UInt32>()
        var seenFields = HashSet<String>()
        var flags = DataCellFlags()

        var remaining = fields.size
        while (remaining > 0) {
            remaining -= 1
            let field = fields[remaining]
            match (field.nameOrIndex) {
                case Name(name) =>
                    if (seenFields.contains(name)) {
                        fields[remaining].nameOrIndex = PostgresNameOrIndex.Duplicate
                        flags.hasDuplicateColumns = true
                    }
                    seenFields.put(name)
                    flags.hasNamedColumns = true
                case Index(index) =>
                    if (seenNumbers.contains(index)) {
                        fields[remaining].nameOrIndex = PostgresNameOrIndex.Duplicate
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
    /// 对应 Bun: PostgresSQLStatement.structure
    public func structure(owner: JscValue, globalObject: JscJSGlobalObject): CachedStructure {
        if (cachedStructure.has()) {
            return cachedStructure
        }
        checkForDuplicateFields()

        var nonDuplicatedCount = fields.size
        for (field in fields) {
            match (field.nameOrIndex) {
                case Duplicate => nonDuplicatedCount -= 1
                case _ => ()
            }
        }

        let ids = Array<ExternColumnIdentifier>(nonDuplicatedCount, item: ExternColumnIdentifier())
        var i: Int64 = 0
        for (field in fields) {
            match (field.nameOrIndex) {
                case Duplicate => continue
                case Name(name) =>
                    ids[i].tag = 2
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
    private func deinit_(): Unit {
        cachedStructure.deinit()
        fields = []
        parameters = []
        signature.deinit()
    }
}

/// Postgres 语句状态
/// 对应 Bun: PostgresSQLStatement.Status
public enum PostgresStatementStatus {
    | Pending
    | Parsing
    | Prepared
    | Failed

    public func isRunning(): Bool {
        return this == Parsing
    }
}

/// Postgres 语句错误
/// 对应 Bun: PostgresSQLStatement.Error
public enum PostgresStatementError {
    | Protocol(ErrorResponse)
    | PostgresError(AnyPostgresError)

    public func toJS(globalObject: JscJSGlobalObject): JscValue {
        match (this) {
            case Protocol(err) => err.toJS(globalObject)
            case PostgresError(err) => postgresErrorToJS(globalObject, None, err)
        }
    }

    public func deinit(): Unit {
        match (this) {
            case Protocol(err) => err.deinit()
            case PostgresError(_) => ()
        }
    }
}

/// 字段描述
/// 对应 Bun: protocol.FieldDescription
public class FieldDescription {
    public var nameOrIndex: PostgresNameOrIndex = PostgresNameOrIndex.Index(0)
    public var typeOid: Int32 = 0
    public var binary: Bool = false

    public init() {}

    public func deinit(): Unit {}

    public func typeTag(): PostgresTag {
        return PostgresTag.fromInt(typeOid)
    }
}

/// Postgres 名称或索引
public enum PostgresNameOrIndex {
    | Name(String)
    | Index(UInt32)
    | Duplicate
}

/// 错误响应
/// 对应 Bun: protocol.ErrorResponse
public class ErrorResponse {
    public var messages: ArrayList<ErrorField> = ArrayList<ErrorField>()

    public init() {}

    public func toJS(globalObject: JscJSGlobalObject): JscValue {
        // 构建错误对象
        var message = ""
        var code = ""
        var severity = ""
        var detail = ""
        var hint = ""

        for (field in messages) {
            match (field) {
                case Message(m) => message = m
                case Code(c) => code = c
                case Severity(s) => severity = s
                case Detail(d) => detail = d
                case Hint(h) => hint = h
                case _ => ()
            }
        }

        let errorCode = if (code == "42601") "ERR_POSTGRES_SYNTAX_ERROR" else "ERR_POSTGRES_SERVER_ERROR"
        return createPostgresError(globalObject, message, errorCode, code, detail, hint, severity)
    }

    public func deinit(): Unit {
        messages = ArrayList<ErrorField>()
    }
}

/// 错误字段
public enum ErrorField {
    | Severity(String)
    | Code(String)
    | Message(String)
    | Detail(String)
    | Hint(String)
    | Position(String)
    | InternalPosition(String)
    | Internal(String)
    | Where(String)
    | Schema(String)
    | Table(String)
    | Column(String)
    | DataType(String)
    | Constraint(String)
    | File(String)
    | Line(String)
    | Routine(String)
    | Other(String)
}

/// Postgres 签名
/// 对应 Bun: postgres/Signature.zig
public class PostgresSignature {
    public var fields: Array<Int32> = []
    public var name: String = ""
    public var query: String = ""
    public var preparedStatementName: String = ""

    public init() {}

    public static func empty(): PostgresSignature {
        return PostgresSignature()
    }

    /// 生成签名
    /// 对应 Bun: Signature.generate
    public static func generate(globalObject: JscJSGlobalObject, query: String,
                                 arrayValue: JscValue, columns: JscValue,
                                 preparedStatementId: UInt64, unnamed: Bool): ?PostgresSignature {
        let sig = PostgresSignature()
        sig.query = query
        sig.name = query

        do {
            let iter = QueryBindingIterator.init(arrayValue, columns, globalObject)
            if (iter == None) {
                return None
            }

            var fields = ArrayList<Int32>()
            var nameBuilder = StringBuilder()
            nameBuilder.append(query)

            var nextValue = iter.getOrThrow().next()
            while (nextValue != None) {
                let value = nextValue.getOrThrow()
                if (value.isEmptyOrUndefinedOrNull()) {
                    fields.append(0)
                    nameBuilder.append(".null")
                } else {
                    let tag = PostgresTag.fromJS(globalObject, value)
                    if (tag != None) {
                        let tagName = tag.getOrThrow().name()
                        nameBuilder.append(".${tagName}")

                        match (tag.getOrThrow()) {
                            case Bool | Int4 | Int8 | Float8 | Int2 | Numeric | Float4 | Bytea =>
                                fields.append(tag.getOrThrow().toInt())
                            case _ =>
                                fields.append(0)
                        }
                    }
                }
                nextValue = iter.getOrThrow().next()
            }

            if (iter.getOrThrow().anyFailed()) {
                return None
            }

            if (!unnamed) {
                let maxNameLen = if (sig.name.size > 40) 40 else sig.name.size
                sig.preparedStatementName = "P${sig.name[0..maxNameLen]}\$${preparedStatementId}"
            }

            sig.fields = fields.toArray()
            return sig
        } catch (_: Exception) {
            return None
        }
    }

    /// 计算哈希
    public func hash(): UInt64 {
        var hasher = Wyhash.init(0)
        hasher.update(name)
        return hasher.final()
    }

    public func deinit(): Unit {
        fields = []
        name = ""
        query = ""
        preparedStatementName = ""
    }
}

/// Postgres 标签
/// 对应 Bun: types.Tag
public enum PostgresTag {
    | Bool
    | Int4
    | Int8
    | Float8
    | Float4
    | Int2
    | Numeric
    | Json
    | Jsonb
    | Timestamp
    | Timestamptz
    | Bytea
    | Text
    | Int4Array
    | Float4Array
    | Int8Array
    | Date
    | BpcharArray
    | VarcharArray
    | CharArray
    | TextArray
    | BoolArray
    | ByteaArray
    | JsonArray
    | JsonbArray
    | TimestamptzArray
    | TimestampArray
    | DateArray
    | TimeArray
    | TimetzArray
    | IntervalArray
    | NumericArray
    | Float8Array
    | Int2Array
    | OidArray
    | XidArray
    | CidArray
    | Cid
    | Xid
    | Oid
    | Time
    | Timetz
    | MoneyArray
    | VarbitArray
    | BitArray
    | Int2vectorArray
    | PathArray
    | XmlArray
    | PointArray
    | LsegArray
    | BoxArray
    | PolygonArray
    | LineArray
    | CidrArray
    | CircleArray
    | Macaddr8Array
    | MacaddrArray
    | InetArray
    | AclitemArray
    | TidArray
    | PgDatabaseArray
    | PgDatabaseArray2

    public static func fromInt(oid: Int32): PostgresTag {
        match (oid) {
            case 16 => Bool
            case 23 => Int4
            case 20 => Int8
            case 701 => Float8
            case 700 => Float4
            case 21 => Int2
            case 1700 => Numeric
            case 114 => Json
            case 3802 => Jsonb
            case 1114 => Timestamp
            case 1184 => Timestamptz
            case 17 => Bytea
            case 25 => Text
            case 1082 => Date
            case _ => Text
        }
    }

    public static func fromJS(globalObject: JscJSGlobalObject, value: JscValue): ?PostgresTag {
        if (value.isEmptyOrUndefinedOrNull()) {
            return Numeric
        }
        if (value.isString()) {
            return Text
        }
        if (value.isDate()) {
            return Timestamptz
        }
        if (value.isTypedArrayOrArrayBuffer()) {
            return Bytea
        }
        if (value.isInt32()) {
            return Int4
        }
        if (value.isAnyInt()) {
            let int_ = value.toInt64()
            if (int_ >= Int64(Int32.MinValue) && int_ <= Int64(Int32.MaxValue)) {
                return Int4
            }
            return Int8
        }
        if (value.isNumber()) {
            return Float8
        }
        if (value.isBoolean()) {
            return Bool
        }
        return Numeric
    }

    public func toInt(): Int32 {
        return match (this) {
            case Bool => 16
            case Int4 => 23
            case Int8 => 20
            case Float8 => 701
            case Float4 => 700
            case Int2 => 21
            case Numeric => 1700
            case Json => 114
            case Jsonb => 3802
            case Timestamp => 1114
            case Timestamptz => 1184
            case Bytea => 17
            case Text => 25
            case Date => 1082
            case _ => 25
        }
    }

    public func name(): String {
        return match (this) {
            case Bool => "bool"
            case Int4 => "int4"
            case Int8 => "int8"
            case Float8 => "float8"
            case Float4 => "float4"
            case Int2 => "int2"
            case Numeric => "numeric"
            case Json => "json"
            case Jsonb => "jsonb"
            case Timestamp => "timestamp"
            case Timestamptz => "timestamptz"
            case Bytea => "bytea"
            case Text => "text"
            case Date => "date"
            case _ => "text"
        }
    }

    public func isBinaryFormatSupported(): Bool {
        return match (this) {
            case Bool | Int4 | Int8 | Float8 | Float4 | Int2 |
                 Timestamp | Timestamptz | Bytea | Date => true
            case _ => false
        }
    }

    public func formatCode(): Int16 {
        return if (isBinaryFormatSupported()) Int16(1) else Int16(0)
    }

    public func tagName(): ?String {
        return name()
    }
}

/// 创建 Postgres 错误 JS 对象
public func createPostgresError(globalObject: JscJSGlobalObject, message: String,
                                  code: String, errno: ?String, detail: ?String,
                                  hint: ?String, severity: ?String): JscValue {
    let optsObj = JscObject.createEmptyObject(globalObject)
    optsObj.put(globalObject, "code", JscValue(code))
    if (errno != None) {
        optsObj.put(globalObject, "errno", JscValue(errno.getOrThrow()))
    }
    optsObj.put(globalObject, "message", JscValue(message))
    if (detail != None) {
        optsObj.put(globalObject, "detail", JscValue(detail.getOrThrow()))
    }
    if (hint != None) {
        optsObj.put(globalObject, "hint", JscValue(hint.getOrThrow()))
    }
    if (severity != None) {
        optsObj.put(globalObject, "severity", JscValue(severity.getOrThrow()))
    }
    return optsObj.toValue()
}
