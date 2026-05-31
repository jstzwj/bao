// MySQL 参数描述符
// 严格翻译自: src/sql/mysql/MySQLParam.zig
package bao_runtime.sql.mysql


/// MySQL 预编译语句参数描述符
/// 对应 Bun: MySQLParam.Param
/// 纯协议层参数描述，与 JSC 无关
public class MySQLParam {
    /// 参数字段类型
    public var paramType: FieldType
    /// 参数标志 (如 UNSIGNED)
    public var flags: ColumnFlags

    public init() {
        paramType = FieldType.MYSQL_TYPE_NULL
        flags = ColumnFlags()
    }

    public init(paramType: FieldType, flags: ColumnFlags) {
        this.paramType = paramType
        this.flags = flags
    }
}
