// 严格翻译自: src/sql_jsc/postgres/protocol/notice_response_jsc.zig
// Postgres 通知响应 JS 转换

package bao_sql_jsc.postgres.protocol

import bao_core.*
import bao_jsc.*
import bao_sql_jsc.postgres.*
import bao_collections.ArrayList

/// 通知响应 JS 转换
/// 对应 Bun: protocol/notice_response_jsc.zig
/// 将 PostgreSQL NoticeResponse 转换为 JS 字符串

/// NoticeResponse 转 JS 字符串
/// 对应 Bun: NoticeResponse.toJS
public func noticeResponseToJS(noticeResponse: NoticeResponse,
                                globalObject: JscJSGlobalObject): JscValue {
    let builder = ArrayList<String>()

    for (msg in noticeResponse.messages) {
        match (msg) {
            case ErrorField.Severity(s) => builder.append(s)
            case ErrorField.Code(c) => builder.append(c)
            case ErrorField.Message(m) => builder.append(m)
            case ErrorField.Detail(d) => builder.append(d)
            case ErrorField.Hint(h) => builder.append(h)
            case _ => ()
        }
        builder.append("\n")
    }

    var result = ""
    for (s in builder) {
        result = result + s
    }
    return JscValue(result)
}

/// 通知响应
/// 对应 Bun: protocol/NoticeResponse
public class NoticeResponse {
    public var messages: ArrayList<ErrorField> = ArrayList<ErrorField>()

    public init() {}
}
