// MySQL JS 请求队列绑定
// 严格翻译自: src/sql_jsc/mysql/MySQLRequestQueue.zig
//
// 管理查询请求队列，支持管道化和非管道化调度。
// 对应 Bun: MySQLRequestQueue
package bao_runtime.sql.mysql

import bao_core.*
import bao_runtime.sql.shared.*

/// MySQL 请求队列 (JSC 层)
/// 对应 Bun: MySQLRequestQueue
/// 管理查询请求的入队、出队和管道化调度
public class MySQLRequestQueueJSC {
    /// 内部队列
    public var requests: ArrayList<JSMySQLQuery>
    /// 已管道化的请求数
    public var pipelinedRequests: UInt32
    /// 非管道化请求数
    public var nonpipelinableRequests: UInt32
    /// 是否正在等待预编译
    public var waitingToPrepare: Bool
    /// 是否准备好接收查询
    public var isReadyForQuery: Bool

    public init() {
        requests = ArrayList<JSMySQLQuery>()
        pipelinedRequests = 0
        nonpipelinableRequests = 0
        waitingToPrepare = false
        isReadyForQuery = true
    }

    /// 是否能执行查询
    /// 对应 Bun: MySQLRequestQueue.canExecuteQuery
    public func canExecuteQuery(connection: JSMySQLConnection): Bool {
        return connection.isAbleToWrite() &&
            isReadyForQuery &&
            nonpipelinableRequests == 0 &&
            pipelinedRequests == 0
    }

    /// 是否能预编译查询
    /// 对应 Bun: MySQLRequestQueue.canPrepareQuery
    public func canPrepareQuery(connection: JSMySQLConnection): Bool {
        return connection.isAbleToWrite() &&
            isReadyForQuery &&
            !waitingToPrepare &&
            pipelinedRequests == 0
    }

    /// 是否能管道化
    /// 对应 Bun: MySQLRequestQueue.canPipeline
    public func canPipeline(connection: JSMySQLConnection): Bool {
        return isReadyForQuery &&
            nonpipelinableRequests == 0 &&
            !waitingToPrepare &&
            connection.isAbleToWrite()
    }

    /// 标记为准备好接收查询
    /// 对应 Bun: MySQLRequestQueue.markAsReadyForQuery
    public func markAsReadyForQuery(): Unit {
        isReadyForQuery = true
    }

    /// 标记为已预编译
    /// 对应 Bun: MySQLRequestQueue.markAsPrepared
    public func markAsPrepared(): Unit {
        waitingToPrepare = false
        if (let Some(request) <- current()) {
            request.markAsPrepared()
        }
    }

    /// 标记当前请求为已完成
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
        // 先清理已完成的请求
        while (requests.size > 0) {
            let request = requests[0]
            if (request.isCompleted()) {
                requests.removeAt(0)
                request.deref()
                continue
            }
            break
        }

        var offset: Int64 = 0
        while (offset < requests.size && connection.isAbleToWrite()) {
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
                if (offset < totalRunning) {
                    offset += totalRunning
                } else {
                    offset += 1
                }
                continue
            }

            // 尝试运行请求
            request.ref()
            request.query.run()
            request.deref()

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
    public func isEmpty(): Bool {
        return requests.size == 0
    }

    /// 入队请求
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

    /// 清理队列 (带 JS 回调)
    /// 对应 Bun: MySQLRequestQueue.clean
    public func clean(reason: ?JSValueRef, queriesArray: JSValueRef): Unit {
        // 交换队列防止重入
        let oldRequests = requests
        requests = ArrayList<JSMySQLQuery>()
        pipelinedRequests = 0
        nonpipelinableRequests = 0
        waitingToPrepare = false

        for (request in oldRequests) {
            defer {
                request.deref()
            }
            if (request.isCompleted()) {
                continue
            }
            if (let Some(r) <- reason) {
                request.rejectWithJSValue(queriesArray, r)
            } else {
                request.reject(queriesArray, MySQLError.ConnectionClosed)
            }
        }
    }

    /// 释放 (不接触 JS)
    /// 对应 Bun: MySQLRequestQueue.deinit
    public func deinit(): Unit {
        for (request in requests) {
            request.markAsFailed()
            request.deref()
        }
        requests = ArrayList<JSMySQLQuery>()
        pipelinedRequests = 0
        nonpipelinableRequests = 0
        waitingToPrepare = false
    }
}
