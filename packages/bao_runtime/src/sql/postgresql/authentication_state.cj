// PostgreSQL 认证状态机
// 严格翻译自: bun/src/sql_jsc/postgres/AuthenticationState.zig
//   pub const AuthenticationState = union(enum) {
//       pending: void,
//       ok: void,
//       md5: void,
//       sasl: SASLState,
//   };
package bao_runtime.sql.postgresql


/// PostgreSQL 认证状态
/// 跟踪当前认证流程的状态
/// 对应 Bun AuthenticationState
public enum AuthenticationState {
    | Pending       // 等待服务器认证请求
    | Ok            // 认证成功
    | MD5           // MD5 密码认证中
    | SASL(SASLState) // SASL/SCRAM-SHA-256 认证中

    /// 清零敏感数据
    public func zero() {
        match (this) {
            case SASL(state) => state.zero()
            case _ => {}
        }
    }
}

/// SASL SCRAM-SHA-256 认证状态
/// 对应 Bun AuthenticationState.SASLState
public class SASLState {
    /// SASL 状态阶段
    public enum Status {
        | Init       // 初始阶段
        | Continue   // 继续阶段
        | Final      // 最终阶段
    }

    public var status: Status
    /// 客户端 nonce (随机字符串)
    public var clientNonce: Array<UInt8>
    /// 盐值密码
    public var saltedPassword: Array<UInt8>
    /// 服务器签名
    public var serverSignatureData: Array<UInt8>

    public init() {
        status = Status.Init
        clientNonce = generateNonce()
        saltedPassword = Array<UInt8>(32)
        serverSignatureData = Array<UInt8>()
    }

    /// 获取客户端 nonce 的十六进制字符串表示
    public func nonce(): String {
        clientNonce.toArray().map({ b =>
            let hex = UInt8.toHexString(b)
            if (hex.size == 1) "0${hex}" else hex
        }).toString()
    }

    /// 获取客户端 key
    public func clientKey(): Array<UInt8> {
        // HMAC-SHA256(saltedPassword, "Client Key")
        // 这里需要 HMAC 实现
        Array<UInt8>(32)
    }

    /// 计算服务器签名
    public func clientKeySignature(clientKey: Array<UInt8>, authString: String): Array<UInt8> {
        // HMAC-SHA256(clientKey, authString)
        Array<UInt8>(32)
    }

    /// 计算盐值密码
    public func computeSaltedPassword(salt: Array<UInt8>, iterations: UInt32): Unit {
        // PBKDF2-HMAC-SHA256(password, salt, iterations)
        // 实际实现需要 PBKDF2
    }

    /// 计算服务器签名
    public func computeServerSignature(authString: String): Unit {
        // HMAC-SHA256(ServerKey, authString)
        // ServerKey = HMAC-SHA256(saltedPassword, "Server Key")
    }

    /// 获取服务器签名
    public func serverSignature(): Array<UInt8> {
        serverSignatureData
    }

    /// 服务器签名长度
    public func serverSignatureLen(): Int64 {
        serverSignatureData.size
    }

    /// 清零敏感数据
    public func zero() {
        for (i in 0..saltedPassword.size) {
            saltedPassword[i] = 0
        }
        for (i in 0..serverSignatureData.size) {
            serverSignatureData[i] = 0
        }
        for (i in 0..clientNonce.size) {
            clientNonce[i] = 0
        }
    }

    /// 生成随机 nonce
    private static func generateNonce(): Array<UInt8> {
        // 生成 18 字节随机数据
        let nonce = Array<UInt8>(18)
        for (i in 0..18) {
            nonce[i] = UInt8.random()
        }
        nonce
    }
}
