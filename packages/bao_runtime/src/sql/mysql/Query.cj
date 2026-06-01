// MySQL Query protocol - simplified stub
package bao_runtime.sql.mysql

import bao_core.*
import bao_sql.*
import bao_sql.mysql.protocol.*
import bao_runtime.sql.shared.*

/// MySQL 查询执行
public class Execute {
    public var paramTypes: Array<MySQLParam>
    public var params: Array<MySQLValueData>

    public init() {
        paramTypes = Array<MySQLParam>()
        params = Array<MySQLValueData>()
    }
}
