// PostgreSQL 通知响应 JSC 绑定
// 严格翻译自: bun/src/sql_jsc/postgres/protocol/notice_response_jsc.zig
//   pub fn toJS(this: NoticeResponse, globalObject: *jsc.JSGlobalObject) JSValue
package bao_runtime.sql.postgresql

import bao_sql.postgres.protocol.*


/// 通知响应 JSC 转换器
/// 对应 Bun notice_response_jsc
/// 将 NoticeResponse 协议消息转为 JS 字符串
public class NoticeResponseJSC {

    /// 将 NoticeResponse 转为 JS 字符串
    /// 对应 Bun NoticeResponse.toJS()
    ///
    /// 通知消息被组合为单个字符串，每行一个字段
    public static func toJS(noticeResponse: NoticeResponse): String {
        var result = ""
        for (field in noticeResponse.messages) {
            result = result + field.value + "\n"
        }
        if (result.size > 0) {
            if (result.size > 0) {
                // Remove last character (trailing newline)
                if (result.size > 1) {
                    var sb = StringBuilder()
                    for (i in 0..result.size - 1) {
                        sb.append(result.toRuneArray()[i])
                    }
                    result = sb.toString()
                }
            }
        }
        return result
    }
}
