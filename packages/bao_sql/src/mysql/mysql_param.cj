// MySQL 参数描述符
// 对应 Bun: src/sql/mysql/MySQLParam.zig
package bao_sql.mysql

/// MySQL 预编译语句参数描述
/// 对应 Bun: MySQLParam.Param (struct)
///
/// 纯参数描述符，被协议层编码器 (Query, PreparedStatement) 使用。
/// 从 MySQLStatement 分离出来，使协议层不依赖 JSC 耦合的语句结构。
public class MySQLParam {
    /// 参数字段类型
    /// 对应 Bun: Param.type FieldType
    public var paramType: FieldType

    /// 参数标志
    /// 对应 Bun: Param.flags ColumnFlags
    public var flags: ColumnFlags

    public init() {
        paramType = FieldType.MYSQL_TYPE_NULL(0x06)
        flags = ColumnFlags()
    }

    public init(paramType: FieldType, flags: ColumnFlags) {
        this.paramType = paramType
        this.flags = flags
    }
}
