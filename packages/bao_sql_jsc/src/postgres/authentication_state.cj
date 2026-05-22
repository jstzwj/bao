// 严格翻译自: src/sql_jsc/postgres/AuthenticationState.zig
// Postgres 认证状态

package bao_sql_jsc.postgres

import bao_core.*
import bao_jsc.*

/// 认证状态
/// 对应 Bun: AuthenticationState
public enum AuthenticationState {
    | Pending
    | None
    | OK
    | SASL(PostgresSASL)
    | MD5
    | `this`
}
