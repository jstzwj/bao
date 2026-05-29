// bao_http h3_client AltSvc - Alt-Svc 头部处理 (RFC 7838)
// 严格翻译自: src/http/h3_client/AltSvc.zig
package bao_http.h3_client

import bao_core.*
import bao_collections.*
import bao_sys.*

@C
foreign func malloc(size: UIntNative): CPointer<Unit>
@C
foreign func free(ptr: CPointer<Unit>): Unit

// ============================================================================
// H3AltSvc - Alt-Svc (RFC 7838) 头部处理
// 严格翻译自: bun/src/http/h3_client/AltSvc.zig
//
// Bun AltSvc:
//   //! Alt-Svc (RFC 7838) header handling for the HTTP/3 client.
//   //! When `--experimental-http3-fetch` is on, `handleResponseMetadata` calls
//   //! `record()` for every `Alt-Svc` header and `start_()` calls `lookup()`
//   //! before opening a TCP socket: if the origin previously advertised `h3`,
//   //! the request is routed onto the QUIC engine instead.
//
// 缓存结构:
//   - Key: "hostname:port" (来源)
//   - Value: Record { h3_port: u16, expires_at: i64 }
//   - 最大条目数: 256
//   - 过期清理: 惰性清理 + 写入时清理
//
// parse() 解析 Alt-Svc 字段值:
//   Alt-Svc = clear / 1#alt-value
//   alt-value = protocol-id "=" alt-authority *( OWS ";" OWS parameter )
//   仅支持同主机 h3 替代 (alt-authority 为 ":port")
// ============================================================================

/// Alt-Svc 条目
/// 严格翻译自: AltSvc.Entry
///   pub const Entry = struct {
///       port: u16,
///       ma: u32 = 86400,
///   };
public class AltSvcEntry {
    /// 替代端口 (QUIC 应连接的端口)
    public var port: Int64

    /// 新鲜度生命周期 (秒, 默认 24 小时)
    public var ma: Int64

    public init(port: Int64, ma: Int64) {
        this.port = port
        this.ma = ma
    }
}

/// Alt-Svc 缓存记录
/// 严格翻译自: AltSvc.Record
///   const Record = struct {
///       h3_port: u16,
///       expires_at: i64,
///   };
public class AltSvcRecord {
    /// H3 替代端口
    public var h3Port: Int64

    /// 过期时间戳 (Unix 秒)
    public var expiresAt: Int64

    public init(h3Port: Int64, expiresAt: Int64) {
        this.h3Port = h3Port
        this.expiresAt = expiresAt
    }
}

/// Alt-Svc 头部处理器
/// 严格翻译自: bun/src/http/h3_client/AltSvc.zig
public class H3AltSvc {
    /// 最大缓存条目数
    /// 严格翻译自: const max_entries = 256
    public static let MAX_ENTRIES: Int64 = 256

    /// Alt-Svc 缓存 (key: "hostname:port" -> Record)
    private var cache: HashMap<String, AltSvcRecord>

    public init() {
        cache = HashMap<String, AltSvcRecord>()
    }

    // ========================================================================
    // parse - 解析 Alt-Svc 字段值
    // 严格翻译自:
    //   pub fn parse(field_value: []const u8) error{Clear}!?Entry {
    //       const value = strings.trim(field_value, " \t");
    //       if (value.len == 0) return null;
    //       if (std.ascii.eqlIgnoreCase(value, "clear")) return error.Clear;
    //       var entries = std.mem.splitScalar(u8, value, ',');
    //       while (entries.next()) |raw_entry| {
    //           // 解析 proto, auth, params
    //           // 仅支持 h3 同主机替代
    //       }
    //       return null;
    //   }
    // ========================================================================

    /// 解析 Alt-Svc 字段值
    /// 严格翻译自: AltSvc.parse
    /// 返回 None = 无有效条目, Some(entry) = 找到 h3 替代, "clear" = 清除缓存
    public func parse(fieldValue: String): ?AltSvcResult {
        let value = fieldValue.trimStart().trimEnd()
        if (value.size == 0) {
            return None
        }
        if (value == "clear" || value == "Clear" || value == "CLEAR") {
            return AltSvcResult.clear
        }

        // 按逗号分割多个条目
        let entries = value.split(",")
        for (rawEntry in entries) {
            let entry = rawEntry.trimStart().trimEnd()
            if (entry.size == 0) {
                continue
            }

            // 按分号分割替代和参数
            let parts = entry.split(";")
            if (parts.size == 0) {
                continue
            }
            let alternative = parts[0].trimStart().trimEnd()

            match (parseEntry(parts, alternative)) {
                case Some(result) => return result
                case None => continue
            }
        }
        return None
    }

    private func parseEntry(parts: Array<String>, alternative: String): ?AltSvcResult {
        match (alternative.indexOf('=')) {
            case Some(idx) => return parseAlternative(parts, alternative, idx)
            case None => return None
        }
    }

    private func parseAlternative(parts: Array<String>, alternative: String, idx: Int64): ?AltSvcResult {
        let proto = sliceString(alternative, 0, idx).trimStart().trimEnd()
        if (proto != "h3" && proto != "H3") {
            return None
        }
        var auth = sliceString(alternative, idx + 1, alternative.size).trimStart().trimEnd()
        if (auth.size >= 2 && auth[0] == 34 && auth[auth.size - 1] == 34) {
            auth = sliceString(auth, 1, auth.size - 1)
        }
        match (auth.lastIndexOf(':')) {
            case Some(ci) => return parseAuthority(parts, auth, ci)
            case None => return None
        }
    }

    private func parseAuthority(parts: Array<String>, auth: String, ci: Int64): ?AltSvcResult {
        if (ci != 0) {
            return None
        }
        match (parseInt64(sliceString(auth, ci + 1, auth.size))) {
            case Some(p) => return parsePort(parts, p)
            case None => return None
        }
    }

    private func parsePort(parts: Array<String>, p: Int64): ?AltSvcResult {
        if (p == 0) { return None }
        var ma: Int64 = 86400
        if (parts.size > 1) {
            for (i in 1..parts.size) {
                let param = parts[i].trimStart().trimEnd()
                match (param.indexOf('=')) {
                    case Some(pi) =>
                        let pName = sliceString(param, 0, pi).trimStart().trimEnd()
                        if (pName == "ma" || pName == "MA") {
                            match (parseInt64(sliceString(param, pi + 1, param.size).trimStart().trimEnd())) {
                                case Some(v) => ma = v
                                case None => ()
                            }
                        }
                    case None => ()
                }
            }
        }
        return AltSvcResult.entry(AltSvcEntry(p, ma))
    }

    // ========================================================================
    // record - 记录 Alt-Svc 条目
    // 严格翻译自:
    //   pub fn record(origin_host: []const u8, origin_port: u16,
    //       field_value: []const u8) void {
    //       const entry = parse(field_value) catch { /* clear */ return; } orelse return;
    //       const now = std.time.timestamp();
    //       // 检查容量
    //       // 插入/更新
    //   }
    // ========================================================================

    /// 记录 Alt-Svc 条目
    /// 严格翻译自: AltSvc.record
    public func record(originHost: String, originPort: Int64, fieldValue: String): Unit {
        let key = originHost + ":" + originPort.toString()
        if (originHost.size > 256) {
            return
        }

        match (parse(fieldValue)) {
            case None => return
            case Some(AltSvcResult.clear) =>
                cache.remove(key)
                return
            case Some(result) =>
                recordResult(key, result)
        }
    }

    // ========================================================================
    // lookup - 查找 Alt-Svc 条目
    // 严格翻译自:
    //   pub fn lookup(origin_host: []const u8, origin_port: u16) ?u16 {
    //       const rec = cache.get(k) orelse return null;
    //       if (std.time.timestamp() >= rec.expires_at) {
    //           cache.fetchRemove(k);
    //           return null;
    //       }
    //       return rec.h3_port;
    //   }
    // ========================================================================

    /// 查找 Alt-Svc 条目
    /// 严格翻译自: AltSvc.lookup
    /// 返回 H3 替代端口, 或 None
    public func lookup(originHost: String, originPort: Int64): ?Int64 {
        let key = originHost + ":" + originPort.toString()
        match (cache.get(key)) {
            case Some(rec) =>
                if (currentTimeSeconds() >= rec.expiresAt) {
                    cache.remove(key)
                    return None
                }
                return rec.h3Port
            case None => return None
        }
    }

    // ========================================================================
    // sweepExpired - 清理过期条目
    // 严格翻译自: AltSvc.sweepExpired
    // ========================================================================

    private func recordResult(key: String, result: AltSvcResult): Unit {
        match (result) {
            case clear =>
                cache.remove(key)
            case entry(entryValue) =>
                let now = currentTimeSeconds()
                var exists = false
                match (cache.get(key)) {
                    case Some(_) => exists = true
                    case None => exists = false
                }
                if (cache.size >= MAX_ENTRIES && !exists) {
                    sweepExpired(now)
                    if (cache.size >= MAX_ENTRIES) {
                        return
                    }
                }
                cache.put(key, AltSvcRecord(entryValue.port, now + entryValue.ma))
        }
    }

    /// 清理过期条目
    /// 严格翻译自: AltSvc.sweepExpired
    public func sweepExpired(now: Int64): Unit {
        let keys = cache.keys().toOwnedSlice()
        for (key in keys) {
            match (cache.get(key)) {
                case Some(rec) =>
                    if (now >= rec.expiresAt) {
                        cache.remove(key)
                    }
                case None => ()
            }
        }
    }

    /// 获取当前时间 (秒)
    /// 对应 Bun: std.time.timestamp()
    private static func currentTimeSeconds(): Int64 {
        // 使用系统时钟获取 Unix 时间戳
        unsafe {
            let ts = malloc(UIntNative(16))
            let tsPtr = CPointer<Int64>(ts)
            // clock_gettime(CLOCK_REALTIME, &ts)
            let rc = clock_gettime(0, ts)
            if (rc == 0) {
                let seconds = tsPtr.read()
                free(ts)
                return seconds
            }
            free(ts)
            return 0
        }
    }

    private static func sliceString(s: String, start: Int64, end: Int64): String {
        let sb = StringBuilder()
        var i = start
        while (i < end && i < s.size) {
            sb.append(s[i].toString())
            i += 1
        }
        return sb.toString()
    }

    private static func parseInt64(s: String): ?Int64 {
        if (s.size == 0) { return None }
        var value: Int64 = 0
        for (ch in s) {
            if (ch < 48 || ch > 57) { return None }
            value = value * 10 + Int64(ch - 48)
        }
        return Some(value)
    }
}

@C
foreign func clock_gettime(clkId: Int32, tp: CPointer<Unit>): Int32

/// Alt-Svc 解析结果
public enum AltSvcResult {
    | clear                  // "clear" 指令 — 清除缓存
    | entry(AltSvcEntry)     // 找到有效的 h3 替代
}
