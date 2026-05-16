// bao_http h3_client AltSvc - Alt-Svc 头部处理 (RFC 7838)
// 严格翻译自: src/http/h3_client/AltSvc.zig
package bao_http.h3_client

import bao_core.*
import bao_collections.*

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
        let value = fieldValue.trim()
        if (value.size == 0) {
            return None
        }
        if (value.toLower() == "clear") {
            return AltSvcResult.clear
        }

        // 按逗号分割多个条目
        let entries = value.split(",")
        for (rawEntry in entries) {
            let entry = rawEntry.trim()
            if (entry.size == 0) {
                continue
            }

            // 按分号分割替代和参数
            let parts = entry.split(";")
            if (parts.size == 0) {
                continue
            }
            let alternative = parts[0].trim()

            // 查找 '='
            let eqIdx = alternative.indexOf('=')
            match (eqIdx) {
                case None => continue
                case Some(idx) => {
                    let proto = alternative.substring(0, idx).trim()
                    // 仅支持 h3
                    if (proto.toLower() != "h3") {
                        continue
                    }

                    var auth = alternative.substring(idx + 1).trim()
                    // 去除引号
                    if (auth.size >= 2 && auth[0] == '"' && auth[auth.size - 1] == '"') {
                        auth = auth.substring(1, auth.size - 1)
                    }
                    // 查找冒号
                    let colonIdx = auth.lastIndexOf(':')
                    match (colonIdx) {
                        case None => continue
                        case Some(ci) => {
                            // 仅支持同主机 (空 uri-host)
                            if (ci != 0) {
                                continue
                            }
                            let portStr = auth.substring(ci + 1)
                            let port = Int64.parse(portStr)
                            match (port) {
                                case Some(p) => {
                                    if (p == 0) { continue }
                                    // 解析参数
                                    var ma: Int64 = 86400
                                    if (parts.size > 1) {
                                        for (i in 1..parts.size) {
                                            let param = parts[i].trim()
                                            let peqIdx = param.indexOf('=')
                                            match (peqIdx) {
                                                case Some(pi) => {
                                                    let pName = param.substring(0, pi).trim()
                                                    if (pName.toLower() == "ma") {
                                                        match (Int64.parse(param.substring(pi + 1).trim())) {
                                                            case Some(v) => ma = v
                                                            case None => ()
                                                        }
                                                    }
                                                }
                                                case None => ()
                                            }
                                        }
                                    }
                                    return AltSvcResult.entry(AltSvcEntry(p, ma))
                                }
                                case None => continue
                            }
                        }
                    }
                }
            }
        }
        return None
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
            case AltSvcResult.clear => {
                cache.remove(key)
                return
            }
            case AltSvcResult.entry(entry) => {
                let now = currentTimeSeconds()
                // 检查容量
                if (cache.size >= MAX_ENTRIES && cache.get(key) == None) {
                    sweepExpired(now)
                    if (cache.size >= MAX_ENTRIES) {
                        return
                    }
                }
                cache.put(key, AltSvcRecord(entry.port, now + entry.ma))
            }
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
            case Some(rec) => {
                if (currentTimeSeconds() >= rec.expiresAt) {
                    cache.remove(key)
                    return None
                }
                return rec.h3Port
            }
            case None => return None
        }
    }

    // ========================================================================
    // sweepExpired - 清理过期条目
    // 严格翻译自: AltSvc.sweepExpired
    // ========================================================================

    /// 清理过期条目
    /// 严格翻译自: AltSvc.sweepExpired
    public func sweepExpired(now: Int64): Unit {
        let keys = cache.keys().toArray()
        for (key in keys) {
            match (cache.get(key)) {
                case Some(rec) => {
                    if (now >= rec.expiresAt) {
                        cache.remove(key)
                    }
                }
                case None => ()
            }
        }
    }

    /// 获取当前时间 (秒)
    private static func currentTimeSeconds(): Int64 {
        // 桩: 实际应使用系统时钟
        return 0
    }
}

/// Alt-Svc 解析结果
public enum AltSvcResult {
    | clear                  // "clear" 指令 — 清除缓存
    | entry(AltSvcEntry)     // 找到有效的 h3 替代
}
