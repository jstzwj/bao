// HMAC.cj - 消息认证码 (Hash-based Message Authentication Code)
// 对应 Bun: src/runtime/crypto/HMAC.zig
// 严格1:1翻译自 Bun HMAC.zig

package bao_runtime

import bao_core.*

// ============================================================================
// HMAC - 消息认证码
// 对应 Bun: HMAC.zig - const HMAC = @This()
// ============================================================================

/// HMAC 消息认证码
/// 对应 Bun: const HMAC = @This()
///
/// ctx: BoringSSL.HMAC_CTX,
/// algorithm: EVP.Algorithm,
public class HMAC {
    public var ctx: HmacCtx
    public var algorithm: EVP.Algorithm

    public init(ctx: HmacCtx, algorithm: EVP.Algorithm) {
        this.ctx = ctx
        this.algorithm = algorithm
    }

    /// 初始化 HMAC
    /// 对应 Bun: pub fn init(algorithm: EVP.Algorithm, key: []const u8) ?*HMAC
    public static func init(algorithm: EVP.Algorithm, key: Array<Byte>): ?HMAC {
        // const md = algorithm.md() orelse return null;
        let md = algorithm.md()
        match (md) {
            case None => return None
            case _ => {}
        }
        let mdVal = md!!

        // var ctx: BoringSSL.HMAC_CTX = undefined;
        // BoringSSL.HMAC_CTX_init(&ctx);
        var ctx = HmacCtx()
        BoringSSL.hmacCtxInit(ctx)

        // if (BoringSSL.HMAC_Init_ex(&ctx, key.ptr, @intCast(key.len), md, null) != 1)
        //     BoringSSL.HMAC_CTX_cleanup(&ctx);
        //     return null;
        if (BoringSSL.hmacInitEx(ctx, key, key.size.toInt64(), mdVal, None) != 1) {
            BoringSSL.hmacCtxCleanup(ctx)
            return None
        }

        // return HMAC.new(.{ .ctx = ctx, .algorithm = algorithm });
        return HMAC(ctx, algorithm)
    }

    /// 更新 HMAC 数据
    /// 对应 Bun: pub fn update(this: *HMAC, data: []const u8) void
    public func update(data: Array<Byte>): Unit {
        // _ = BoringSSL.HMAC_Update(&this.ctx, data.ptr, data.len);
        BoringSSL.hmacUpdate(this.ctx, data, data.size.toInt64())
    }

    /// 获取 HMAC 输出大小
    /// 对应 Bun: pub fn size(this: *const HMAC) usize
    public func size(): Int64 {
        // return BoringSSL.HMAC_size(&this.ctx);
        return BoringSSL.hmacSize(this.ctx)
    }

    /// 复制 HMAC
    /// 对应 Bun: pub fn copy(this: *HMAC) !*HMAC
    public func copy(): ?HMAC {
        // var ctx: BoringSSL.HMAC_CTX = undefined;
        // BoringSSL.HMAC_CTX_init(&ctx);
        var newCtx = HmacCtx()
        BoringSSL.hmacCtxInit(newCtx)

        // if (BoringSSL.HMAC_CTX_copy(&ctx, &this.ctx) != 1)
        //     BoringSSL.HMAC_CTX_cleanup(&ctx);
        //     return error.BoringSSLError;
        if (BoringSSL.hmacCtxCopy(newCtx, this.ctx) != 1) {
            BoringSSL.hmacCtxCleanup(newCtx)
            return None
        }

        // return HMAC.new(.{ .ctx = ctx, .algorithm = this.algorithm });
        return HMAC(newCtx, this.algorithm)
    }

    /// 获取 HMAC 最终结果
    /// 对应 Bun: pub fn final(this: *HMAC, out: []u8) []u8
    public func final(out: Array<Byte>): Array<Byte> {
        // var outlen: c_uint = undefined;
        var outLen = Array<UInt32>([0.toUInt32()])

        // _ = BoringSSL.HMAC_Final(&this.ctx, out.ptr, &outlen);
        BoringSSL.hmacFinal(this.ctx, out, outLen)

        // return out[0..outlen];
        let len = outLen[0].toInt64()
        if (len > 0 && len <= out.size) {
            return out[0..len]
        }
        return Array<Byte>()
    }

    /// 释放 HMAC
    /// 对应 Bun: pub fn deinit(this: *HMAC) void
    public func deinit(): Unit {
        // BoringSSL.HMAC_CTX_cleanup(&this.ctx);
        BoringSSL.hmacCtxCleanup(this.ctx)
        // bun.destroy(this);
    }
}
