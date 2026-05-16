// Valkey JS 类定义 - RedisClient 的 JS 原型方法、Getter/Setter 与内部值注册
// 严格翻译自: bun/src/runtime/valkey_jsc/valkey.classes.ts
//
// 原始 TypeScript 文件通过 codegen/define 宏声明 JS 类的:
//   - 类配置: sharedThis, construct, finalize, memoryCost 等
//   - Getter/Setter: connected, onconnect, onclose, bufferedAmount
//   - ~160+ 原型方法: 每个方法映射到 js_valkey_functions 中的对应函数
//   - 内部值: onconnect, onclose, connectionPromise, hello, subscriptionCallbackMap
package bao_runtime.valkey

import bao_core.*
import bao_collections.*
import bao_valkey.*

// ============================================================================
// RedisClientClass - RedisClient JS 类定义
// 严格翻译自: valkey.classes.ts - define({ name: "RedisClient", ... })
//   define({
//     name: "RedisClient",
//     sharedThis: true,
//     construct: true,
//     constructNeedsThis: true,
//     call: false,
//     finalize: true,
//     configurable: false,
//     JSType: "0b11101110",
//     memoryCost: true,
//     proto: { ... },
//     values: ["onconnect", "onclose", "connectionPromise", "hello", "subscriptionCallbackMap"],
//   })
// ============================================================================

/// RedisClient JS 类注册信息
/// 对应 Bun valkey.classes.ts 中的 define({...})
///
/// 类配置:
///   - sharedThis: true           -> 用户实现使用 &self，生发 this: &T 桩
///   - construct: true            -> 支持构造函数
///   - constructNeedsThis: true   -> 构造函数需要 this 引用
///   - call: false                -> 不支持直接调用 (非函数对象)
///   - finalize: true             -> 支持终结器 (GC 清理)
///   - configurable: false        -> 属性不可配置
///   - JSType: "0b11101110"       -> JS 类型标记位
///   - memoryCost: true           -> 支持内存成本查询
public class RedisClientClass {

    // ========================================================================
    // Getter 定义
    // 严格翻译自: valkey.classes.ts - proto 中的 getter 定义
    // ========================================================================

    /// Getter: connected
    /// 原始: connected: { getter: "getConnected" }
    public static let GETTER_CONNECTED: GetterDef = GetterDef(
        jsName: "connected",
        nativeFn: "getConnected"
    )

    /// Getter: bufferedAmount
    /// 原始: bufferedAmount: { getter: "getBufferedAmount" }
    public static let GETTER_BUFFERED_AMOUNT: GetterDef = GetterDef(
        jsName: "bufferedAmount",
        nativeFn: "getBufferedAmount"
    )

    // ========================================================================
    // Getter/Setter 对定义
    // 严格翻译自: valkey.classes.ts - proto 中的 getter+setter 定义
    // ========================================================================

    /// Getter/Setter: onconnect
    /// 原始: onconnect: { getter: "getOnConnect", setter: "setOnConnect", this: true }
    public static let PROP_ON_CONNECT: PropertyDef = PropertyDef(
        jsName: "onconnect",
        getterFn: "getOnConnect",
        setterFn: "setOnConnect",
        needsThis: true
    )

    /// Getter/Setter: onclose
    /// 原始: onclose: { getter: "getOnClose", setter: "setOnClose", this: true }
    public static let PROP_ON_CLOSE: PropertyDef = PropertyDef(
        jsName: "onclose",
        getterFn: "getOnClose",
        setterFn: "setOnClose",
        needsThis: true
    )

    // ========================================================================
    // 原型方法定义 (~160+ 方法)
    // 严格翻译自: valkey.classes.ts - proto 中的所有 fn+length 定义
    // 每个条目对应原始文件中的一个 proto 条目，格式为:
    //   jsName: { fn: "nativeFunctionName", length: argumentCount }
    // length 未指定时默认为 -1 (表示可变参数)
    // ========================================================================

    /// 所有原型方法的注册表
    /// 对应 Bun proto 中的全部方法条目
    public static let PROTOTYPE_METHODS: ArrayList<MethodDef> = buildPrototypeMethods()

    /// 构建全部原型方法定义列表
    /// 严格按原始 valkey.classes.ts proto 中的顺序排列
    private static func buildPrototypeMethods(): ArrayList<MethodDef> {
        let methods = ArrayList<MethodDef>()

        // -- 连接/控制方法 --
        // connect: { fn: "jsConnect", length: 0 }
        methods.append(MethodDef("connect", "jsConnect", 0))
        // close: { fn: "jsDisconnect", length: 0 }
        methods.append(MethodDef("close", "jsDisconnect", 0))
        // send: { fn: "jsSend", length: 2 }
        methods.append(MethodDef("send", "jsSend", 2))
        // duplicate: { fn: "duplicate" }
        methods.append(MethodDef("duplicate", "duplicate", -1))

        // -- 字符串命令 --
        // get: { fn: "get", length: 1 }
        methods.append(MethodDef("get", "get", 1))
        // getBuffer: { fn: "getBuffer", length: 1 }
        methods.append(MethodDef("getBuffer", "getBuffer", 1))
        // set: { fn: "set", length: 2 }
        methods.append(MethodDef("set", "set", 2))
        // del: { fn: "del", length: 1 }
        methods.append(MethodDef("del", "del", 1))
        // append: { fn: "append" }
        methods.append(MethodDef("append", "append", -1))
        // getset: { fn: "getset" }
        methods.append(MethodDef("getset", "getset", -1))
        // getdel: { fn: "getdel" }
        methods.append(MethodDef("getdel", "getdel", -1))
        // getex: { fn: "getex" }
        methods.append(MethodDef("getex", "getex", -1))
        // getrange: { fn: "getrange", length: 3 }
        methods.append(MethodDef("getrange", "getrange", 3))
        // setrange: { fn: "setrange", length: 3 }
        methods.append(MethodDef("setrange", "setrange", 3))
        // strlen: { fn: "strlen" }
        methods.append(MethodDef("strlen", "strlen", -1))
        // substr: { fn: "substr" }
        methods.append(MethodDef("substr", "substr", -1))
        // mget: { fn: "mget" }
        methods.append(MethodDef("mget", "mget", -1))
        // mset: { fn: "mset" }
        methods.append(MethodDef("mset", "mset", -1))
        // msetnx: { fn: "msetnx" }
        methods.append(MethodDef("msetnx", "msetnx", -1))
        // setnx: { fn: "setnx" }
        methods.append(MethodDef("setnx", "setnx", -1))
        // setex: { fn: "setex", length: 3 }
        methods.append(MethodDef("setex", "setex", 3))
        // psetex: { fn: "psetex", length: 3 }
        methods.append(MethodDef("psetex", "psetex", 3))

        // -- 自增/自减命令 --
        // incr: { fn: "incr", length: 1 }
        methods.append(MethodDef("incr", "incr", 1))
        // incrby: { fn: "incrby", length: 2 }
        methods.append(MethodDef("incrby", "incrby", 2))
        // incrbyfloat: { fn: "incrbyfloat", length: 2 }
        methods.append(MethodDef("incrbyfloat", "incrbyfloat", 2))
        // decr: { fn: "decr", length: 1 }
        methods.append(MethodDef("decr", "decr", 1))
        // decrby: { fn: "decrby", length: 2 }
        methods.append(MethodDef("decrby", "decrby", 2))

        // -- 键命令 --
        // exists: { fn: "exists", length: 1 }
        methods.append(MethodDef("exists", "exists", 1))
        // expire: { fn: "expire", length: 2 }
        methods.append(MethodDef("expire", "expire", 2))
        // expireat: { fn: "expireat", length: 2 }
        methods.append(MethodDef("expireat", "expireat", 2))
        // expiretime: { fn: "expiretime" }
        methods.append(MethodDef("expiretime", "expiretime", -1))
        // pexpire: { fn: "pexpire", length: 2 }
        methods.append(MethodDef("pexpire", "pexpire", 2))
        // pexpireat: { fn: "pexpireat", length: 2 }
        methods.append(MethodDef("pexpireat", "pexpireat", 2))
        // pexpiretime: { fn: "pexpiretime" }
        methods.append(MethodDef("pexpiretime", "pexpiretime", -1))
        // persist: { fn: "persist" }
        methods.append(MethodDef("persist", "persist", -1))
        // pttl: { fn: "pttl" }
        methods.append(MethodDef("pttl", "pttl", -1))
        // ttl: { fn: "ttl", length: 1 }
        methods.append(MethodDef("ttl", "ttl", 1))
        // keys: { fn: "keys" }
        methods.append(MethodDef("keys", "keys", -1))
        // randomkey: { fn: "randomkey", length: 0 }
        methods.append(MethodDef("randomkey", "randomkey", 0))
        // type: { fn: "type", length: 1 }
        methods.append(MethodDef("type", "type", 1))
        // rename: { fn: "rename", length: 2 }
        methods.append(MethodDef("rename", "rename", 2))
        // renamenx: { fn: "renamenx", length: 2 }
        methods.append(MethodDef("renamenx", "renamenx", 2))
        // unlink: { fn: "unlink" }
        methods.append(MethodDef("unlink", "unlink", -1))
        // touch: { fn: "touch" }
        methods.append(MethodDef("touch", "touch", -1))
        // copy: { fn: "copy" }
        methods.append(MethodDef("copy", "copy", -1))
        // dump: { fn: "dump" }
        methods.append(MethodDef("dump", "dump", -1))
        // scan: { fn: "scan" }
        methods.append(MethodDef("scan", "scan", -1))

        // -- 位操作命令 --
        // getbit: { fn: "getbit", length: 2 }
        methods.append(MethodDef("getbit", "getbit", 2))
        // setbit: { fn: "setbit", length: 3 }
        methods.append(MethodDef("setbit", "setbit", 3))
        // bitcount: { fn: "bitcount" }
        methods.append(MethodDef("bitcount", "bitcount", -1))

        // -- Hash 命令 --
        // hget: { fn: "hget", length: 2 }
        methods.append(MethodDef("hget", "hget", 2))
        // hset: { fn: "hset", length: 2 }
        methods.append(MethodDef("hset", "hset", 2))
        // hsetnx: { fn: "hsetnx", length: 3 }
        methods.append(MethodDef("hsetnx", "hsetnx", 3))
        // hmset: { fn: "hmset", length: 2 }
        methods.append(MethodDef("hmset", "hmset", 2))
        // hmget: { fn: "hmget", length: 2 }
        methods.append(MethodDef("hmget", "hmget", 2))
        // hdel: { fn: "hdel", length: 2 }
        methods.append(MethodDef("hdel", "hdel", 2))
        // hexists: { fn: "hexists", length: 2 }
        methods.append(MethodDef("hexists", "hexists", 2))
        // hgetall: { fn: "hgetall" }
        methods.append(MethodDef("hgetall", "hgetall", -1))
        // hkeys: { fn: "hkeys" }
        methods.append(MethodDef("hkeys", "hkeys", -1))
        // hvals: { fn: "hvals" }
        methods.append(MethodDef("hvals", "hvals", -1))
        // hlen: { fn: "hlen" }
        methods.append(MethodDef("hlen", "hlen", -1))
        // hincrby: { fn: "hincrby", length: 3 }
        methods.append(MethodDef("hincrby", "hincrby", 3))
        // hincrbyfloat: { fn: "hincrbyfloat", length: 3 }
        methods.append(MethodDef("hincrbyfloat", "hincrbyfloat", 3))
        // hstrlen: { fn: "hstrlen" }
        methods.append(MethodDef("hstrlen", "hstrlen", -1))
        // hrandfield: { fn: "hrandfield", length: 1 }
        methods.append(MethodDef("hrandfield", "hrandfield", 1))
        // hscan: { fn: "hscan", length: 2 }
        methods.append(MethodDef("hscan", "hscan", 2))
        // hgetdel: { fn: "hgetdel", length: 2 }
        methods.append(MethodDef("hgetdel", "hgetdel", 2))
        // hgetex: { fn: "hgetex", length: 2 }
        methods.append(MethodDef("hgetex", "hgetex", 2))
        // hsetex: { fn: "hsetex", length: 3 }
        methods.append(MethodDef("hsetex", "hsetex", 3))
        // hexpire: { fn: "hexpire", length: 3 }
        methods.append(MethodDef("hexpire", "hexpire", 3))
        // hexpireat: { fn: "hexpireat", length: 3 }
        methods.append(MethodDef("hexpireat", "hexpireat", 3))
        // hexpiretime: { fn: "hexpiretime", length: 2 }
        methods.append(MethodDef("hexpiretime", "hexpiretime", 2))
        // hpersist: { fn: "hpersist", length: 2 }
        methods.append(MethodDef("hpersist", "hpersist", 2))
        // hpexpire: { fn: "hpexpire", length: 3 }
        methods.append(MethodDef("hpexpire", "hpexpire", 3))
        // hpexpireat: { fn: "hpexpireat", length: 3 }
        methods.append(MethodDef("hpexpireat", "hpexpireat", 3))
        // hpexpiretime: { fn: "hpexpiretime", length: 2 }
        methods.append(MethodDef("hpexpiretime", "hpexpiretime", 2))
        // hpttl: { fn: "hpttl", length: 2 }
        methods.append(MethodDef("hpttl", "hpttl", 2))
        // httl: { fn: "httl", length: 2 }
        methods.append(MethodDef("httl", "httl", 2))

        // -- List 命令 --
        // lpush: { fn: "lpush" }
        methods.append(MethodDef("lpush", "lpush", -1))
        // lpushx: { fn: "lpushx" }
        methods.append(MethodDef("lpushx", "lpushx", -1))
        // rpush: { fn: "rpush" }
        methods.append(MethodDef("rpush", "rpush", -1))
        // rpushx: { fn: "rpushx" }
        methods.append(MethodDef("rpushx", "rpushx", -1))
        // lpop: { fn: "lpop" }
        methods.append(MethodDef("lpop", "lpop", -1))
        // rpop: { fn: "rpop" }
        methods.append(MethodDef("rpop", "rpop", -1))
        // rpoplpush: { fn: "rpoplpush", length: 2 }
        methods.append(MethodDef("rpoplpush", "rpoplpush", 2))
        // lindex: { fn: "lindex", length: 2 }
        methods.append(MethodDef("lindex", "lindex", 2))
        // linsert: { fn: "linsert", length: 4 }
        methods.append(MethodDef("linsert", "linsert", 4))
        // llen: { fn: "llen" }
        methods.append(MethodDef("llen", "llen", -1))
        // lmove: { fn: "lmove", length: 4 }
        methods.append(MethodDef("lmove", "lmove", 4))
        // lmpop: { fn: "lmpop", length: 2 }
        methods.append(MethodDef("lmpop", "lmpop", 2))
        // lpos: { fn: "lpos", length: 2 }
        methods.append(MethodDef("lpos", "lpos", 2))
        // lrange: { fn: "lrange", length: 3 }
        methods.append(MethodDef("lrange", "lrange", 3))
        // lrem: { fn: "lrem", length: 3 }
        methods.append(MethodDef("lrem", "lrem", 3))
        // lset: { fn: "lset", length: 3 }
        methods.append(MethodDef("lset", "lset", 3))
        // ltrim: { fn: "ltrim", length: 3 }
        methods.append(MethodDef("ltrim", "ltrim", 3))
        // blpop: { fn: "blpop", length: 2 }
        methods.append(MethodDef("blpop", "blpop", 2))
        // brpop: { fn: "brpop", length: 2 }
        methods.append(MethodDef("brpop", "brpop", 2))
        // brpoplpush: { fn: "brpoplpush", length: 3 }
        methods.append(MethodDef("brpoplpush", "brpoplpush", 3))
        // blmove: { fn: "blmove", length: 5 }
        methods.append(MethodDef("blmove", "blmove", 5))
        // blmpop: { fn: "blmpop", length: 3 }
        methods.append(MethodDef("blmpop", "blmpop", 3))

        // -- Set 命令 --
        // sadd: { fn: "sadd", length: 2 }
        methods.append(MethodDef("sadd", "sadd", 2))
        // srem: { fn: "srem", length: 2 }
        methods.append(MethodDef("srem", "srem", 2))
        // smembers: { fn: "smembers", length: 1 }
        methods.append(MethodDef("smembers", "smembers", 1))
        // sismember: { fn: "sismember", length: 2 }
        methods.append(MethodDef("sismember", "sismember", 2))
        // smismember: { fn: "smismember", length: 2 }
        methods.append(MethodDef("smismember", "smismember", 2))
        // srandmember: { fn: "srandmember", length: 1 }
        methods.append(MethodDef("srandmember", "srandmember", 1))
        // spop: { fn: "spop", length: 1 }
        methods.append(MethodDef("spop", "spop", 1))
        // scard: { fn: "scard" }
        methods.append(MethodDef("scard", "scard", -1))
        // sdiff: { fn: "sdiff", length: 1 }
        methods.append(MethodDef("sdiff", "sdiff", 1))
        // sdiffstore: { fn: "sdiffstore", length: 2 }
        methods.append(MethodDef("sdiffstore", "sdiffstore", 2))
        // sinter: { fn: "sinter", length: 1 }
        methods.append(MethodDef("sinter", "sinter", 1))
        // sintercard: { fn: "sintercard", length: 1 }
        methods.append(MethodDef("sintercard", "sintercard", 1))
        // sinterstore: { fn: "sinterstore", length: 2 }
        methods.append(MethodDef("sinterstore", "sinterstore", 2))
        // sscan: { fn: "sscan", length: 2 }
        methods.append(MethodDef("sscan", "sscan", 2))
        // sunion: { fn: "sunion", length: 1 }
        methods.append(MethodDef("sunion", "sunion", 1))
        // sunionstore: { fn: "sunionstore", length: 2 }
        methods.append(MethodDef("sunionstore", "sunionstore", 2))
        // smove: { fn: "smove" }
        methods.append(MethodDef("smove", "smove", -1))
        // spublish: { fn: "spublish" }
        methods.append(MethodDef("spublish", "spublish", -1))

        // -- Sorted Set 命令 --
        // zadd: { fn: "zadd", length: 3 }
        methods.append(MethodDef("zadd", "zadd", 3))
        // zcard: { fn: "zcard" }
        methods.append(MethodDef("zcard", "zcard", -1))
        // zcount: { fn: "zcount", length: 3 }
        methods.append(MethodDef("zcount", "zcount", 3))
        // zlexcount: { fn: "zlexcount", length: 3 }
        methods.append(MethodDef("zlexcount", "zlexcount", 3))
        // zincrby: { fn: "zincrby", length: 3 }
        methods.append(MethodDef("zincrby", "zincrby", 3))
        // zmscore: { fn: "zmscore" }
        methods.append(MethodDef("zmscore", "zmscore", -1))
        // zpopmax: { fn: "zpopmax" }
        methods.append(MethodDef("zpopmax", "zpopmax", -1))
        // zpopmin: { fn: "zpopmin" }
        methods.append(MethodDef("zpopmin", "zpopmin", -1))
        // zrandmember: { fn: "zrandmember" }
        methods.append(MethodDef("zrandmember", "zrandmember", -1))
        // zrange: { fn: "zrange", length: 3 }
        methods.append(MethodDef("zrange", "zrange", 3))
        // zrangebylex: { fn: "zrangebylex", length: 3 }
        methods.append(MethodDef("zrangebylex", "zrangebylex", 3))
        // zrangebyscore: { fn: "zrangebyscore", length: 3 }
        methods.append(MethodDef("zrangebyscore", "zrangebyscore", 3))
        // zrangestore: { fn: "zrangestore", length: 4 }
        methods.append(MethodDef("zrangestore", "zrangestore", 4))
        // zrank: { fn: "zrank" }
        methods.append(MethodDef("zrank", "zrank", -1))
        // zrem: { fn: "zrem", length: 2 }
        methods.append(MethodDef("zrem", "zrem", 2))
        // zremrangebylex: { fn: "zremrangebylex", length: 3 }
        methods.append(MethodDef("zremrangebylex", "zremrangebylex", 3))
        // zremrangebyrank: { fn: "zremrangebyrank", length: 3 }
        methods.append(MethodDef("zremrangebyrank", "zremrangebyrank", 3))
        // zremrangebyscore: { fn: "zremrangebyscore", length: 3 }
        methods.append(MethodDef("zremrangebyscore", "zremrangebyscore", 3))
        // zrevrange: { fn: "zrevrange", length: 3 }
        methods.append(MethodDef("zrevrange", "zrevrange", 3))
        // zrevrangebylex: { fn: "zrevrangebylex", length: 3 }
        methods.append(MethodDef("zrevrangebylex", "zrevrangebylex", 3))
        // zrevrangebyscore: { fn: "zrevrangebyscore", length: 3 }
        methods.append(MethodDef("zrevrangebyscore", "zrevrangebyscore", 3))
        // zrevrank: { fn: "zrevrank" }
        methods.append(MethodDef("zrevrank", "zrevrank", -1))
        // zscore: { fn: "zscore" }
        methods.append(MethodDef("zscore", "zscore", -1))
        // zscan: { fn: "zscan", length: 2 }
        methods.append(MethodDef("zscan", "zscan", 2))
        // zdiff: { fn: "zdiff", length: 1 }
        methods.append(MethodDef("zdiff", "zdiff", 1))
        // zdiffstore: { fn: "zdiffstore", length: 2 }
        methods.append(MethodDef("zdiffstore", "zdiffstore", 2))
        // zinter: { fn: "zinter", length: 2 }
        methods.append(MethodDef("zinter", "zinter", 2))
        // zintercard: { fn: "zintercard", length: 1 }
        methods.append(MethodDef("zintercard", "zintercard", 1))
        // zinterstore: { fn: "zinterstore", length: 3 }
        methods.append(MethodDef("zinterstore", "zinterstore", 3))
        // zunion: { fn: "zunion", length: 2 }
        methods.append(MethodDef("zunion", "zunion", 2))
        // zunionstore: { fn: "zunionstore", length: 3 }
        methods.append(MethodDef("zunionstore", "zunionstore", 3))
        // zmpop: { fn: "zmpop", length: 2 }
        methods.append(MethodDef("zmpop", "zmpop", 2))
        // bzmpop: { fn: "bzmpop", length: 3 }
        methods.append(MethodDef("bzmpop", "bzmpop", 3))
        // bzpopmin: { fn: "bzpopmin", length: 2 }
        methods.append(MethodDef("bzpopmin", "bzpopmin", 2))
        // bzpopmax: { fn: "bzpopmax", length: 2 }
        methods.append(MethodDef("bzpopmax", "bzpopmax", 2))

        // -- HyperLogLog 命令 --
        // pfadd: { fn: "pfadd" }
        methods.append(MethodDef("pfadd", "pfadd", -1))

        // -- Pub/Sub 命令 --
        // ping: { fn: "ping" }
        methods.append(MethodDef("ping", "ping", -1))
        // publish: { fn: "publish" }
        methods.append(MethodDef("publish", "publish", -1))
        // subscribe: { fn: "subscribe" }
        methods.append(MethodDef("subscribe", "subscribe", -1))
        // unsubscribe: { fn: "unsubscribe" }
        methods.append(MethodDef("unsubscribe", "unsubscribe", -1))
        // psubscribe: { fn: "psubscribe" }
        methods.append(MethodDef("psubscribe", "psubscribe", -1))
        // punsubscribe: { fn: "punsubscribe" }
        methods.append(MethodDef("punsubscribe", "punsubscribe", -1))
        // pubsub: { fn: "pubsub" }
        methods.append(MethodDef("pubsub", "pubsub", -1))

        // -- 其他命令 --
        // script: { fn: "script" }
        methods.append(MethodDef("script", "script", -1))
        // select: { fn: "select" }
        methods.append(MethodDef("select", "select", -1))

        methods
    }

    // ========================================================================
    // 内部值定义
    // 严格翻译自: valkey.classes.ts - values: [...]
    //   values: ["onconnect", "onclose", "connectionPromise", "hello",
    //            "subscriptionCallbackMap"]
    // ========================================================================

    /// 内部值名称列表 - 这些值存储在 JS 对象的内部槽位中
    /// 对应 Bun values 数组
    public static let INTERNAL_VALUES: ArrayList<String> = buildInternalValues()

    private static func buildInternalValues(): ArrayList<String> {
        let values = ArrayList<String>()
        values.append("onconnect")
        values.append("onclose")
        values.append("connectionPromise")
        values.append("hello")
        values.append("subscriptionCallbackMap")
        values
    }

    // ========================================================================
    // 类配置常量
    // 严格翻译自: valkey.classes.ts - define 参数
    // ========================================================================

    /// 类名
    public static let CLASS_NAME: String = "RedisClient"

    /// 是否共享 this
    /// 对应 sharedThis: true
    public static let SHARED_THIS: Bool = true

    /// 是否支持构造
    /// 对应 construct: true
    public static let CONSTRUCT: Bool = true

    /// 构造是否需要 this
    /// 对应 constructNeedsThis: true
    public static let CONSTRUCT_NEEDS_THIS: Bool = true

    /// 是否支持直接调用
    /// 对应 call: false
    public static let CALL: Bool = false

    /// 是否支持终结器
    /// 对应 finalize: true
    public static let FINALIZE: Bool = true

    /// 是否可配置
    /// 对应 configurable: false
    public static let CONFIGURABLE: Bool = false

    /// JS 类型标记
    /// 对应 JSType: "0b11101110"
    public static let JS_TYPE: String = "0b11101110"

    /// 是否支持内存成本查询
    /// 对应 memoryCost: true
    public static let MEMORY_COST: Bool = true
}

// ============================================================================
// 辅助类型定义 - 用于描述 JS 类的属性、方法和 Getter
// ============================================================================

/// Getter 定义 - 对应 proto 中的 { getter: "..." } 条目
public class GetterDef {
    /// JS 属性名
    public var jsName: String
    /// 原生函数名
    public var nativeFn: String

    public init(jsName: String, nativeFn: String) {
        this.jsName = jsName
        this.nativeFn = nativeFn
    }
}

/// 属性定义 (Getter+Setter) - 对应 proto 中的 { getter: "...", setter: "...", this: bool } 条目
public class PropertyDef {
    /// JS 属性名
    public var jsName: String
    /// Getter 原生函数名
    public var getterFn: String
    /// Setter 原生函数名
    public var setterFn: String
    /// 是否需要 this 引用
    public var needsThis: Bool

    public init(jsName: String, getterFn: String, setterFn: String, needsThis: Bool) {
        this.jsName = jsName
        this.getterFn = getterFn
        this.setterFn = setterFn
        this.needsThis = needsThis
    }
}

/// 方法定义 - 对应 proto 中的 { fn: "...", length: N } 条目
public class MethodDef {
    /// JS 方法名
    public var jsName: String
    /// 原生函数名
    public var nativeFn: String
    /// 参数数量 (-1 表示可变参数)
    public var length: Int64

    public init(jsName: String, nativeFn: String, length: Int64) {
        this.jsName = jsName
        this.nativeFn = nativeFn
        this.length = length
    }
}
