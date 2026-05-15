// 严格翻译自: src/sql_jsc/mysql/MySQLRequestQueue.zig
// MySQL 请求队列 - 管理流水线和非流水线请求

package bao_sql_jsc

import bao_core.*
import bao_jsc.*

/// MySQL 请求队列
/// 对应 Bun: MySQLRequestQueue
/// 管理 MySQL 连接上的请求调度：流水线化、准备和执行
public class MySQLRequestQueue {
    var requests: ArrayList<JSMySQLQuery> = ArrayList<JSMySQLQuery>()
    var pipelinedRequests: Int64 = 0
    var nonpipelinableRequests: Int64 = 0
    var waitingToPrepare: Bool = false
    var isReadyForQuery: Bool = true

    public init() {}

    /// 能否执行查询
    /// 对应 Bun: MySQLRequestQueue.canExecuteQuery
    public func canExecuteQuery(connection: JSMySQLConnection): Bool {
        return connection.connection.isAbleToWrite() &&
            isReadyForQuery &&
            nonpipelinableRequests == 0 &&
            pipelinedRequests == 0
    }

    /// 能否准备查询
    /// 对应 Bun: MySQLRequestQueue.canPrepareQuery
    public func canPrepareQuery(connection: JSMySQLConnection): Bool {
        return connection.connection.isAbleToWrite() &&
            isReadyForQuery &&
            !waitingToPrepare &&
            pipelinedRequests == 0
    }

    /// 能否流水线
    /// 对应 Bun: MySQLRequestQueue.canPipeline
    public func canPipeline(connection: JSMySQLConnection): Bool {
        return isReadyForQuery &&
            nonpipelinableRequests == 0 &&
            !waitingToPrepare &&
            connection.connection.isAbleToWrite()
    }

    /// 标记为查询就绪
    /// 对应 Bun: MySQLRequestQueue.markAsReadyForQuery
    public func markAsReadyForQuery(): Unit {
        isReadyForQuery = true
    }

    /// 标记为已准备
    /// 对应 Bun: MySQLRequestQueue.markAsPrepared
    public func markAsPrepared(): Unit {
        waitingToPrepare = false
        let current = current()
        if (current != None) {
            current.getOrThrow().markAsPrepared()
        }
    }

    /// 标记当前请求完成
    /// 对应 Bun: MySQLRequestQueue.markCurrentRequestAsFinished
    public func markCurrentRequestAsFinished(item: JSMySQLQuery): Unit {
        waitingToPrepare = false
        if (item.isBeingPrepared()) {
            item.markAsPrepared()
        } else if (item.isRunning()) {
            if (item.isPipelined()) {
                pipelinedRequests -= 1
            } else {
                nonpipelinableRequests -= 1
            }
        }
    }

    /// 推进队列
    /// 对应 Bun: MySQLRequestQueue.advance
    public func advance(connection: JSMySQLConnection): Unit {
        var offset: Int64 = 0

        // 清理已完成的请求
        while (requests.size > 0) {
            let request = requests[0]
            if (request.isCompleted()) {
                requests.removeAt(0)
                request.deref()
                continue
            }
            break
        }

        while (offset < requests.size && connection.connection.isAbleToWrite()) {
            let request = requests[offset]

            if (request.isCompleted()) {
                if (offset > 0) {
                    offset += 1
                    continue
                }
                requests.removeAt(0)
                request.deref()
                continue
            }

            if (request.isBeingPrepared()) {
                waitingToPrepare = true
                return
            }

            if (request.isRunning()) {
                let totalRunning = pipelinedRequests + nonpipelinableRequests
                offset = if (offset < totalRunning) totalRunning else offset + 1
                continue
            }

            do {
                request.run(connection)
            } catch (_: Exception) {
                connection.onError(request, AnyMySQLError.UnknownError)
                if (offset == 0) {
                    requests.removeAt(0)
                    request.deref()
                }
                offset += 1
                continue
            }

            if (request.isBeingPrepared()) {
                connection.resetConnectionTimeout()
                isReadyForQuery = false
                waitingToPrepare = true
                return
            } else if (request.isRunning()) {
                connection.resetConnectionTimeout()
                isReadyForQuery = false

                if (request.isPipelined()) {
                    pipelinedRequests += 1
                    if (canPipeline(connection)) {
                        offset += 1
                        continue
                    }
                    return
                }
                nonpipelinableRequests += 1
            }
            return
        }
    }

    /// 是否为空
    /// 对应 Bun: MySQLRequestQueue.isEmpty
    public func isEmpty(): Bool {
        return requests.size == 0
    }

    /// 添加请求
    /// 对应 Bun: MySQLRequestQueue.add
    public func add(request: JSMySQLQuery): Unit {
        if (request.isBeingPrepared()) {
            isReadyForQuery = false
            waitingToPrepare = true
        } else if (request.isRunning()) {
            isReadyForQuery = false
            if (request.isPipelined()) {
                pipelinedRequests += 1
            } else {
                nonpipelinableRequests += 1
            }
        }
        request.ref()
        requests.append(request)
    }

    /// 获取当前请求
    /// 对应 Bun: MySQLRequestQueue.current
    public func current(): ?JSMySQLQuery {
        if (requests.size == 0) {
            return None
        }
        return requests[0]
    }

    /// 清理队列
    /// 对应 Bun: MySQLRequestQueue.clean
    public func clean(reason: ?JscValue, queriesArray: JscValue): Unit {
        let oldRequests = requests
        requests = ArrayList<JSMySQLQuery>()
        pipelinedRequests = 0
        nonpipelinableRequests = 0
        waitingToPrepare = false

        for (request in oldRequests) {
            defer { request.deref() }
            if (request.isCompleted()) {
                continue
            }
            if (reason != None) {
                request.rejectWithJSValue(queriesArray, reason.getOrThrow())
            } else {
                request.reject(queriesArray, AnyMySQLError.ConnectionClosed)
            }
        }
    }

    /// 释放资源
    /// 对应 Bun: MySQLRequestQueue.deinit
    public func deinit(): Unit {
        for (request in requests) {
            request.markAsFailed()
            request.deref()
        }
        pipelinedRequests = 0
        nonpipelinableRequests = 0
        waitingToPrepare = false
        requests = ArrayList<JSMySQLQuery>()
    }
}
