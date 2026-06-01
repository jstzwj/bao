// PostgreSQL 认证消息解码
// 严格翻译自: bun/src/sql/postgres/protocol/Authentication.zig
//   pub const Authentication = union(enum) { Ok, ClearTextPassword, MD5Password, SASL, ... };
package bao_runtime.sql.postgresql

import bao_runtime.sql.shared.*
import std.convert.*

/// PostgreSQL 认证消息
/// 对应 Bun Authentication
public enum AuthenticationMessage {
    | Ok                            // 认证成功 (code 0)
    | KerberosV5                    // Kerberos V5 认证 (code 2)
    | ClearTextPassword             // 明文密码认证 (code 3)
    | MD5Password(Array<UInt8>)     // MD5 密码认证，包含 4 字节盐值 (code 5)
    | GSS                           // GSSAPI 认证 (code 7)
    | GSSContinue(SQLData)          // GSSAPI 继续认证 (code 8)
    | SSPI                          // SSPI 认证 (code 9)
    | SASL                          // SASL 认证开始 (code 10)
    | SASLContinue(SASLContinueData) // SASL 继续认证 (code 11)
    | SASLFinal(SQLData)            // SASL 最终认证 (code 12)
    | Unknown                       // 未知认证方法

    /// 释放资源
    public func deinit() {
        match (this) {
            case SASLContinue(data) =>
                data.data.deinit()
            case SASLFinal(data) =>
                data.deinit()
            case GSSContinue(data) =>
                data.deinit()
            case _ => ()
        }
    }
}

/// SASL 继续认证数据
/// 对应 Bun Authentication.SASLContinue
public class SASLContinueData {
    public var data: SQLData          // 原始数据
    public var r: String              // 服务端 nonce
    public var s: String              // 盐值 (base64)
    public var i: String              // 迭代次数

    public init(data: SQLData, r: String, s: String, i: String) {
        this.data = data
        this.r = r
        this.s = s
        this.i = i
    }

    /// 获取迭代次数
    /// 对应 Bun SASLContinue.iterationCount()
    public func iterationCount(): ?UInt32 {
        try {
            Some(UInt32(Int64.parse(i, radix: 10)))
        } catch (_: Exception) {
            None
        }
    }
}

/// 认证消息解码器
/// 对应 Bun Authentication.decodeInternal()
public class AuthenticationDecoder {

    /// 从读取器解码认证消息
    public static func decode(reader: ProtocolReader): ?AuthenticationMessage {
        // 读取消息长度
        let messageLength = reader.readLength()
        match (messageLength) {
            case None => return None
            case Some(_) => ()
        }

        // 读取认证类型码
        let authType = reader.readUInt32()
        match (authType) {
            case None => return None
            case Some(v) =>
                return decodeByCode(reader, v)
        }
    }

    private static func decodeByCode(reader: ProtocolReader, code: UInt32): ?AuthenticationMessage {
        match (code) {
            case 0 => Some(AuthenticationMessage.Ok)  // AuthenticationOk
            case 2 => Some(AuthenticationMessage.KerberosV5)
            case 3 => Some(AuthenticationMessage.ClearTextPassword)
            case 5 =>
                // MD5Password: 4 字节盐值
                match (reader.readBytes(4)) {
                    case Some(salt) => Some(AuthenticationMessage.MD5Password(salt))
                    case None => None
                }
            case 7 => Some(AuthenticationMessage.GSS)
            case 8 =>
                // GSSContinue: 剩余数据
                match (reader.readData(reader.remaining())) {
                    case Some(data) => Some(AuthenticationMessage.GSSContinue(data))
                    case None => None
                }
            case 9 => Some(AuthenticationMessage.SSPI)
            case 10 => Some(AuthenticationMessage.SASL)  // SASL 认证开始
            case 11 =>
                // SASLContinue: 解析 r, s, i 参数
                match (reader.readNullTerminatedBytes()) {
                    case Some(bytes) =>
                        var sb = StringBuilder()
                        for (b in bytes) {
                            sb.append(Rune(Int32(b)))
                        }
                        let str = sb.toString()
                        let parts = str.split(",")
                        var r = ""
                        var s = ""
                        var ii = ""
                        for (part in parts) {
                            if (part.size > 2) {
                                let key = part[0]
                                let value = part[2..].toString()
                                if (key == 114) {  // 'r'
                                    r = value
                                } else if (key == 115) {  // 's'
                                    s = value
                                } else if (key == 105) {  // 'i'
                                    ii = value
                                }
                            }
                        }
                        let data = SQLData.fromTemporary(bytes)
                        Some(AuthenticationMessage.SASLContinue(
                            SASLContinueData(data, r, s, ii)
                        ))
                    case None => None
                }
            case 12 =>
                // SASLFinal: 剩余数据
                match (reader.readData(reader.remaining())) {
                    case Some(data) => Some(AuthenticationMessage.SASLFinal(data))
                    case None => None
                }
            case _ => Some(AuthenticationMessage.Unknown)
        }
    }
}
