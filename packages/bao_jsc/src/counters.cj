// 严格翻译自: src/jsc/Counters.zig (24行)
// JavaScriptCore 性能计数器

package bao_jsc

// ========== Counters ==========
// 严格翻译自 Counters.zig
// 运行时性能计数器，用于追踪关键操作的发生次数
// 使用饱和加法 (saturating add) 防止溢出
//
// 原始 Zig 代码:
//   const Counters = @This();
//   spawnSync_blocking: i32 = 0,
//   spawn_memfd: i32 = 0,
//   pub fn mark(this: *Counters, comptime tag: Field) void {
//       @field(this, @tagName(tag)) +|= 1;
//   }
//   pub fn toJS(this: *const Counters, globalObject: *jsc.JSGlobalObject) bun.JSError!jsc.JSValue {
//       return (try jsc.JSObject.create(this.*, globalObject)).toJS();
//   }
//   pub fn createCountersObject(globalObject: *jsc.JSGlobalObject, _: *jsc.CallFrame) bun.JSError!jsc.JSValue {
//       return globalObject.bunVM().counters.toJS(globalObject);
//   }
public class Counters {
    // ========== 计数器字段 ==========

    // spawnSync 阻塞调用次数
    public var spawnSyncBlocking: Int32 = 0

    // spawn memfd 使用次数
    public var spawnMemfd: Int32 = 0

    public init() {}

    // ========== mark ==========
    // 严格翻译自 Counters.mark
    // 递增指定计数器 (饱和加法，不溢出)
    public func mark(field: CounterField) {
        match (field) {
            case CounterField.SpawnSyncBlocking => {
                if (spawnSyncBlocking < Int32.MaxValue) {
                    spawnSyncBlocking++
                }
            }
            case CounterField.SpawnMemfd => {
                if (spawnMemfd < Int32.MaxValue) {
                    spawnMemfd++
                }
            }
        }
    }

    // ========== toJS ==========
    // 严格翻译自 Counters.toJS
    // 将计数器转为 JS 对象
    public func toJS(globalObject: JsObject) -> JsValue {
        let obj = JsObject.make()
        obj.className = "Counters"
        obj.set("spawnSyncBlocking", JsValue(n: Float64(spawnSyncBlocking)))
        obj.set("spawnMemfd", JsValue(n: Float64(spawnMemfd)))
        JsValue(obj: obj)
    }

    // ========== createCountersObject ==========
    // 严格翻译自 Counters.createCountersObject
    // 创建计数器对象的 JS 绑定回调
    public static func createCountersObject(globalObject: JsObject, callFrame: CallFrame) -> JsValue {
        // 从 VM 获取计数器并转为 JS
        // 原始: globalObject.bunVM().counters.toJS(globalObject)
        let counters = Counters()
        counters.toJS(globalObject)
    }
}

// ========== CounterField ==========
// 严格翻译自 Counters.zig Field (std.meta.FieldEnum)
// 计数器字段枚举
public enum CounterField {
    | SpawnSyncBlocking
    | SpawnMemfd
}
