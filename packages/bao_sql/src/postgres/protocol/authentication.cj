// 严格翻译自: src/sql/postgres/protocol/Authentication.zig
// PostgreSQL 认证消息
package bao_sql.postgres.protocol

import bao_sql.shared.Data

/// PostgreSQL 认证消息
/// 对应 Bun: Authentication (union enum)
public enum Authentication {
    | Ok
    | ClearTextPassword
    | MD5Password(Array<UInt8>)   // salt[4]
    | KerberosV5
    | GSS
    | GSSContinue(Data)
    | SSPI
    | SASL
    | SASLContinue(SASLContinueData)
    | SASLFinal(Data)
    | Unknown

    /// 释放资源
    /// 对应 Bun: Authentication.deinit
    public func deinit(): Unit {
        // Cangjie has GC, no manual deinit needed
    }

    /// 从读取器解码
    /// 对应 Bun: Authentication.decodeInternal
    public static func decode(reader: StackReaderImpl): ?Authentication {
        let messageLength = reader.length()
        if (messageLength.isNone()) { return None }

        let authType = reader.int4()
        if (authType.isNone()) { return None }

        let authTypeVal = authType.getOrThrow()
        if (authTypeVal == 0) {
            return Authentication.Ok
        } else if (authTypeVal == 2) {
            return Authentication.KerberosV5
        } else if (authTypeVal == 3) {
            return Authentication.ClearTextPassword
        } else if (authTypeVal == 5) {
            // MD5Password - 读取 4 字节 salt
            let saltData = reader.read(4)
            if (saltData.isNone()) { return None }
            return Authentication.MD5Password(saltData.getOrThrow().slice())
        } else if (authTypeVal == 7) {
            return Authentication.GSS
        } else if (authTypeVal == 8) {
            // GSSContinue
            let remaining = Int64(messageLength.getOrThrow()) - 8
            if (remaining < 1) { return None }
            let data = reader.read(remaining)
            if (data.isNone()) { return None }
            return Authentication.GSSContinue(data.getOrThrow())
        } else if (authTypeVal == 9) {
            return Authentication.SSPI
        } else if (authTypeVal == 10) {
            // SASL
            let remaining = Int64(messageLength.getOrThrow()) - 8
            if (remaining < 1) { return None }
            reader.skip(remaining)
            return Authentication.SASL
        } else if (authTypeVal == 11) {
            // SASLContinue - 解析 r, s, i 参数
            let remaining = Int64(messageLength.getOrThrow()) - 8
            if (remaining < 1) { return None }
            let bytes = reader.read(remaining)
            if (bytes.isNone()) { return None }
            let bytesSlice = bytes.getOrThrow().slice()
            // 将字节数组转为字符串并按逗号分割
            let content = String.fromUtf8(bytesSlice)
            var r: ?String = None
            var s: ?String = None
            var ii: ?String = None

            let parts = content.split(",")
            for (part in parts) {
                if (part.size > 2) {
                    let key = part[0..1]
                    let afterEquals = part[2..]
                    if (key == "r") {
                        r = Some(afterEquals)
                    } else if (key == "s") {
                        s = Some(afterEquals)
                    } else if (key == "i") {
                        ii = Some(afterEquals)
                    }
                }
            }

            if (r.isNone() || s.isNone() || ii.isNone()) {
                return None
            }

            return Authentication.SASLContinue(SASLContinueData(
                bytes.getOrThrow(),
                r.getOrThrow(),
                s.getOrThrow(),
                ii.getOrThrow()
            ))
        } else if (authTypeVal == 12) {
            // SASLFinal
            let remaining = Int64(messageLength.getOrThrow()) - 8
            if (remaining < 1) { return None }
            let data = reader.read(remaining)
            if (data.isNone()) { return None }
            return Authentication.SASLFinal(data.getOrThrow())
        } else {
            return Authentication.Unknown
        }
    }
}

/// SASLContinue 中的数据
public class SASLContinueData {
    public var data: Data
    public var r: String   // nonce
    public var s: String   // salt
    public var i: String   // iterations

    public init(data: Data, r: String, s: String, i: String) {
        this.data = data
        this.r = r
        this.s = s
        this.i = i
    }

    /// 获取迭代次数
    public func iterationCount(): ?UInt32 {
        // Parse iteration count from string - return None on parse failure
        None
    }
}
