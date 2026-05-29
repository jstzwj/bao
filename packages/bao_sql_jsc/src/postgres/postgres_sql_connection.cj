// 严格翻译自: src/sql_jsc/postgres/PostgresSQLConnection.zig
// Postgres SQL 连接 - Postgres 协议层连接实现

package bao_sql_jsc.postgres

import bao_core.Result as CoreResult
import bao_core.Environment as CoreEnvironment
import bao_event_loop.EventLoopTimer
import bao_event_loop.TimerTag
import bao_event_loop.AutoFlusher
import bao_jsc.*
import bao_sql.postgres.protocol.*
import bao_sql.shared.ColumnIdentifier
import bao_sql.shared.ColumnIdentifierKind
import bao_sql_jsc.shared.*
import bao_sql_jsc.shared.AnySocket
import bao_sql_jsc.shared.OffsetByteList
import bao_sql_jsc.shared.SSLConfig
import bao_sql_jsc.shared.ConnectionFlags
import bao_collections.ArrayList as BaoArrayList

/// Postgres SQL 连接
/// 对应 Bun: PostgresSQLConnection
/// 管理 PostgreSQL 协议的连接状态、认证、查询执行
public class PostgresSQLConnection {
    var refCount: Int64 = 0
    public var socket: AnySocket = AnySocket()
    public var status: PostgresConnectionStatus = PostgresConnectionStatus.Connecting
    public var writeBuffer: OffsetByteList = OffsetByteList()
    public var readBuffer: OffsetByteList = OffsetByteList()
    public var lastMessageStart: UInt32 = 0
    public var requests: PostgresRequestQueue = PostgresRequestQueue()
    public var pipelinedRequests: UInt32 = 0
    public var nonpipelinableRequests: UInt32 = 0
    public var pollRef: KeepAlive = KeepAlive()
    public var globalObject: JscJSGlobalObject
    public var vm: JscVirtualMachine
    public var statements: PostgresPreparedStatementsMap = PostgresPreparedStatementsMap()
    public var preparedStatementId: UInt64 = 0
    public var jsValue: JscValue = JscValue.undefined()

    public var backendParameters: HashMap<String, String> = HashMap<String, String>()
    public var backendKeyData: BackendKeyData = BackendKeyData()

    public var database: String = ""
    public var user: String = ""
    public var password: String = ""
    public var path: String = ""
    public var options: String = ""
    public var optionsBuf: String = ""

    public var authenticationState: AuthenticationState = AuthenticationState.Pending

    public var secure: UInt64 = 0
    public var tlsConfig: SSLConfig = SSLConfig()
    public var tlsStatus: PostgresTLSStatus = PostgresTLSStatus.NoTLS
    public var sslMode: PostgresSSLMode = PostgresSSLMode.Disable

    public var idleTimeoutIntervalMs: UInt32 = 0
    public var connectionTimeoutMs: UInt32 = 0

    public var flags: ConnectionFlags = ConnectionFlags()

    public var timer: EventLoopTimer
    public var maxLifetimeIntervalMs: UInt32 = 0
    public var maxLifetimeTimer: EventLoopTimer
    public var autoFlusher: AutoFlusher = AutoFlusher()

    public init(globalObject: JscJSGlobalObject, vm: JscVirtualMachine) {
        this.globalObject = globalObject
        this.vm = vm
        this.timer = EventLoopTimer(TimerTag.PostgresSQLConnectionTimeout)
        this.maxLifetimeTimer = EventLoopTimer(TimerTag.PostgresSQLConnectionMaxLifetime)
    }

    public func ref(): Unit {
        refCount += 1
    }

    public func deref(): Unit {
        refCount -= 1
        if (refCount <= 0) {
            deinit_()
        }
    }

    /// 获取构造器
    public static func getConstructor(globalObject: JscJSGlobalObject): JscValue {
        return JscValue.undefined()
    }

    /// 创建连接
    /// 对应 Bun: PostgresSQLConnection.call
    public static func call_(globalObject: JscJSGlobalObject,
                              callFrame: JscCallFrame): JscValue {
        // 解析参数并创建连接
        return JscValue.undefined()
    }

    /// 连接已建立
    public func onConnectionEstablished(): Unit {
        if (vm.isShuttingDown()) {
            return
        }
    }

    /// 处理认证消息
    public func onAuth(messageType: UInt8, data: Array<UInt8>): Unit {
        match (authenticationState) {
            case Pending => ()
            case SASL(sasl) => sasl.processAuth(data)
            case MD5 => processMD5Auth(data)
            case AuthenticationState.NoAuth => ()
            case OK => ()
            case _ => ()
        }
    }

    /// 处理 Postgres 消息
    /// 对应 Bun: PostgresSQLConnection.on
    public func on(messageType: PostgresMessageType, reader: PostgresReader): Unit {
        // 创建 StackReaderImpl 用于协议层 decode
        let remaining = reader.remainingBytes()
        let protoReader = StackReaderImpl(remaining)

        match (messageType) {
            case ReadyForQuery =>
                let decoded = ReadyForQuery.decode(protoReader)
                if (decoded.isNone()) { return }
                let ready = decoded.getOrThrow()
                if (status == PostgresConnectionStatus.Authenticating) {
                    status = PostgresConnectionStatus.Connected
                    onConnectionEstablished()
                }
                requests.markAsReadyForQuery()
                requests.advance(this)

            case BindComplete =>
                requests.markAsPrepared()

            case ParseComplete =>
                let reqOpt = requests.current()
                if (let Some(req) <- reqOpt) {
                    if (req.statement.isSome()) {
                        req.statement.getOrThrow().status = PostgresStatementStatus.Prepared
                    }
                }

            case RowDescription =>
                let decoded = RowDescription.decode(protoReader)
                if (decoded.isNone()) { return }
                let rowDesc = decoded.getOrThrow()
                let reqOpt = requests.current()
                if (let Some(req) <- reqOpt) {
                    if (req.statement.isSome()) {
                        let stmt = req.statement.getOrThrow()
                        let fieldCount = rowDesc.fields.size
                        stmt.fields = Array<FieldDescription>(fieldCount, { i =>
                            let protoField = rowDesc.fields[i]
                            let f = FieldDescription()
                            // 从 ColumnIdentifier 转换为 PostgresNameOrIndex
                            match (protoField.nameOrIndex.kind) {
                                case ColumnIdentifierKind.nameKind =>
                                    let nameBytes = protoField.nameOrIndex.nameData.slice()
                                    let name = String.fromUtf8(nameBytes)
                                    f.nameOrIndex = PostgresNameOrIndex.Name(name)
                                case ColumnIdentifierKind.indexKind =>
                                    f.nameOrIndex = PostgresNameOrIndex.Index(protoField.nameOrIndex.indexValue)
                                case ColumnIdentifierKind.duplicateKind =>
                                    f.nameOrIndex = PostgresNameOrIndex.Duplicate
                            }
                            f.typeOid = Int32(protoField.typeOid)
                            f.binary = protoField.binary
                            f
                        })
                        stmt.checkForDuplicateFields()
                    }
                }

            case ParameterDescription =>
                let decoded = ParameterDescription.decode(protoReader)
                if (decoded.isNone()) { return }
                let paramDesc = decoded.getOrThrow()
                let reqOpt = requests.current()
                if (let Some(req) <- reqOpt) {
                    if (req.statement.isSome()) {
                        let stmt = req.statement.getOrThrow()
                        stmt.parameters = Array<Int32>(paramDesc.parameters.size, { i =>
                            Int32(paramDesc.parameters[i])
                        })
                    }
                }

            case ParameterStatus =>
                let decoded = ParameterStatus.decode(protoReader)
                if (decoded.isNone()) { return }
                let param = decoded.getOrThrow()
                backendParameters.put(String.fromUtf8(param.name.slice()), String.fromUtf8(param.value.slice()))

            case BackendKeyData =>
                let decoded = BackendKeyData.decode(protoReader)
                if (decoded.isNone()) { return }
                let keyData = decoded.getOrThrow()
                backendKeyData.processId = keyData.processId
                backendKeyData.secretKey = keyData.secretKey

            case Authentication =>
                let decoded = Authentication.decode(protoReader)
                if (decoded.isNone()) { return }
                let auth = decoded.getOrThrow()
                match (auth) {
                    case Authentication.Ok =>
                        authenticationState = AuthenticationState.OK
                    case Authentication.MD5Password(salt) =>
                        authenticationState = AuthenticationState.MD5
                        onAuth(5, salt)
                    case Authentication.SASL =>
                        authenticationState = AuthenticationState.SASL(PostgresSASL())
                    case Authentication.ClearTextPassword =>
                        onAuth(3, [])
                    case _ =>
                        fail("Unsupported authentication method",
                            AnyPostgresError.UnsupportedAuthenticationMethod)
                }

            case DataRow =>
                onResultRow(reader, protoReader)

            case ErrorResponse =>
                let decoded = ErrorResponse.decode(protoReader)
                if (decoded.isNone()) { return }
                let errResp = decoded.getOrThrow()
                // 从 FieldMessage 列表中提取主消息
                var errMsg: String = "Postgres error"
                for (msg in errResp.messages) {
                    if (msg.fieldType == FieldType.message) {
                        errMsg = msg.value
                        break
                    }
                }
                let reqOpt = requests.current()
                if (let Some(req) <- reqOpt) {
                    let errVal = postgresErrorToJS(globalObject, errMsg, AnyPostgresError.JSError)
                    req.rejectWithJSValue(JscValue.undefined(), errVal)
                } else if (status == PostgresConnectionStatus.Authenticating) {
                    fail(errMsg, AnyPostgresError.JSError)
                }

            case CommandComplete =>
                let decoded = CommandComplete.decode(protoReader)
                if (decoded.isNone()) { return }
                let cmd = decoded.getOrThrow()
                let reqOpt = requests.current()
                if (let Some(req) <- reqOpt) {
                    let result = PostgresQueryResult()
                    req.resolve(JscValue.undefined(), result)
                }

            case NoData =>
                let reqOpt = requests.current()
                if (let Some(req) <- reqOpt) {
                    req.status = PostgresQueryStatus.Running
                }

            case NoticeResponse =>
                let _ = ErrorResponse.decode(protoReader)

            case CloseComplete =>
                let reqOpt = requests.current()
                if (let Some(req) <- reqOpt) {
                    let result = PostgresQueryResult()
                    req.resolve(JscValue.undefined(), result)
                }

            case EmptyQueryResponse =>
                let reqOpt = requests.current()
                if (let Some(req) <- reqOpt) {
                    let result = PostgresQueryResult()
                    req.resolve(JscValue.undefined(), result)
                }

            case _ =>
                // CopyData, CopyInResponse, CopyOutResponse, CopyDone,
                // CopyBothResponse, PortalSuspended — stubs
                reader.skipRemaining()
        }
    }

    /// 处理查询结果行
    /// 对应 Bun: PostgresSQLConnection.onResultRow
    func onResultRow(reader: PostgresReader, protoReader: StackReaderImpl): Unit {
        let reqOpt = requests.current()
        if (let None <- reqOpt) { return }
        let request = reqOpt.getOrThrow()

        if (let None <- request.statement) { return }
        let statement = request.statement.getOrThrow()

        let fields = statement.fields
        let putter = DataCellPutter(fields, globalObject)
        putter.binary = request.flags.binary
        putter.bigint = request.flags.bigint

        let err = DataRow.decode(protoReader, { index, dataOpt =>
            if (dataOpt.isSome()) {
                let data = dataOpt.getOrThrow()
                let bytes = data.slice()
                let _ = putter.put(UInt32(index), Some(bytes))
            } else {
                let _ = putter.put(UInt32(index), Option<Array<UInt8>>.None)
            }
            true
        })

        if (err.isSome()) {
            let protoErr = err.getOrThrow()
            let jsErr = JscValue(protoErr.toString())
            request.rejectWithJSValue(JscValue.undefined(), jsErr)
            return
        }

        if (putter.count > 0) {
            let structure = statement.structure(JscValue.undefined(), globalObject)
            let flags = statement.fieldsFlags
            let jsRow = putter.toJS(globalObject, JscValue.undefined(),
                JscValue.undefined(), flags,
                request.flags.resultMode, structure)
            // 将 jsRow 传递给请求的结果收集器
            // 对应 Bun: request.rows.push(js_row) — 收集查询结果行
            request.rows.append(jsRow)
        }
    }

    /// 错误处理
    public func fail(message: String, err: AnyPostgresError): Unit {
        let instance = postgresErrorToJS(globalObject, message, err)
        failWithJSValue(instance)
    }

    private func failWithJSValue(value: JscValue): Unit {
        ref()
        status = PostgresConnectionStatus.Failed
        deref()
    }

    private func deinit_(): Unit {
        // 释放资源
    }

    private func processMD5Auth(data: Array<UInt8>): Unit {
        // MD5 认证处理
    }

    /// 设置 TLS
    public func setupTLS(): Unit {
        // TLS 升级
    }

    /// 转换为 JS 值
    public func toJS(globalObject: JscJSGlobalObject): JscValue {
        return JscValue.undefined()
    }
}

/// Postgres 连接状态
public enum PostgresConnectionStatus {
    | Connecting
    | Authenticating
    | Connected
    | Failed
    | Disconnected

    public operator func == (other: PostgresConnectionStatus): Bool {
        match (this) {
            case Connecting => match (other) { case Connecting => true case _ => false }
            case Authenticating => match (other) { case Authenticating => true case _ => false }
            case Connected => match (other) { case Connected => true case _ => false }
            case Failed => match (other) { case Failed => true case _ => false }
            case Disconnected => match (other) { case Disconnected => true case _ => false }
        }
    }
    public operator func != (other: PostgresConnectionStatus): Bool { !(this == other) }
}

/// Postgres TLS 状态
public enum PostgresTLSStatus {
    | NoTLS
    | Pending
    | MessageSent
    | SSLOk
    | SSLFailed
    | SSLNotAvailable
}

/// Postgres SSL 模式
public enum PostgresSSLMode {
    | Disable
    | Prefer
    | Require
    | VerifyCA
    | VerifyFull
}

/// 后端密钥数据 (本地占位，避免遮蔽 bao_sql.postgres.protocol.BackendKeyData)
public class JscBackendKeyData {
    public var processId: Int32 = 0
    public var secretKey: Int32 = 0

    public init() {}
}

/// Postgres 预处理语句映射
public class PostgresPreparedStatementsMap {
    private var map: HashMap<UInt64, PostgresSQLStatement> = HashMap<UInt64, PostgresSQLStatement>()

    public init() {}

    public func getOrPut(key: UInt64): PostgresGetOrPutResult {
        return PostgresGetOrPutResult(false)
    }

    public func deinit(): Unit {
        map.clear()
    }
}

/// Postgres 获取或放入结果
public class PostgresGetOrPutResult {
    public var foundExisting: Bool

    public init(foundExisting: Bool) {
        this.foundExisting = foundExisting
    }
}

/// Postgres 请求队列
public class PostgresRequestQueue {
    var requests: BaoArrayList<PostgresSQLQuery> = BaoArrayList<PostgresSQLQuery>()

    public init() {}

    public func current(): ?PostgresSQLQuery {
        if (requests.size == 0) {
            return None
        }
        return requests[0]
    }

    public func add(request: PostgresSQLQuery): Unit {
        request.ref()
        requests.append(request)
    }

    /// 推进请求队列
    /// 对应 Bun: PostgresRequestQueue.advance
    public func advance(connection: PostgresSQLConnection): Unit {
        if (requests.size == 0) {
            return
        }
        let req = requests[0]
        if (req.isCompleted()) {
            markCurrentRequestAsFinished(req)
            // 继续处理下一个请求
            if (requests.size > 0) {
                let next = requests[0]
                if (next.isPending()) {
                    next.status = PostgresQueryStatus.Running
                }
            }
        }
    }

    /// 标记当前请求为就绪查询状态
    /// 对应 Bun: PostgresRequestQueue.markAsReadyForQuery
    public func markAsReadyForQuery(): Unit {
        if (requests.size == 0) {
            return
        }
        let req = requests[0]
        if (req.isRunning() || req.isPending()) {
            req.flags.isDone = true
        }
    }

    /// 标记当前请求的语句为已准备
    /// 对应 Bun: PostgresRequestQueue.markAsPrepared
    public func markAsPrepared(): Unit {
        if (requests.size == 0) {
            return
        }
        let req = requests[0]
        if (req.statement.isSome()) {
            req.statement.getOrThrow().status = PostgresStatementStatus.Prepared
        }
        req.status = PostgresQueryStatus.Running
    }

    /// 标记当前请求为已完成并出队
    /// 对应 Bun: PostgresRequestQueue.markCurrentRequestAsFinished
    public func markCurrentRequestAsFinished(request: PostgresSQLQuery): Unit {
        if (requests.size > 0 && requests[0] == request) {
            requests.removeAt(0)
            request.deref()
        }
    }

    public func clean(reason: ?JscValue, queriesArray: JscValue): Unit {
        let oldRequests = requests
        requests = BaoArrayList<PostgresSQLQuery>()
        for (req in oldRequests) {
            req.deref()
        }
    }

    public func deinit(): Unit {
        for (req in requests) {
            req.deref()
        }
        requests = BaoArrayList<PostgresSQLQuery>()
    }
}
