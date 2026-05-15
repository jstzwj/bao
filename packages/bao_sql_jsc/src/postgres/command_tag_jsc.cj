// 严格翻译自: src/sql_jsc/postgres/command_tag_jsc.zig
// Postgres 命令标签 JS 转换

package bao_sql_jsc.postgres

import bao_core.*
import bao_jsc.*

/// 命令标签 JS 转换
/// 对应 Bun: command_tag_jsc.zig
/// 将 PostgreSQL 命令标签转换为 JS 值

/// 扩展 PostgresCommandTag 的 JS 转换方法
public func commandTagToJSTag(tag: PostgresCommandTag, globalObject: JscJSGlobalObject): JscValue {
    return match (tag.tagType) {
        case 1 => JscValue(1)  // INSERT
        case 2 => JscValue(2)  // DELETE
        case 3 => JscValue(3)  // UPDATE
        case 4 => JscValue(4)  // MERGE
        case 5 => JscValue(5)  // SELECT
        case 6 => JscValue(6)  // MOVE
        case 7 => JscValue(7)  // FETCH
        case 8 => JscValue(8)  // COPY
        case _ => JscValue(tag.otherTag)
    }
}

/// 命令标签转 JS 数字
public func commandTagToJSNumber(tag: PostgresCommandTag): JscValue {
    return match (tag.tagType) {
        case 0 => JscValue(0)
        case _ => JscValue(tag.count)
    }
}
