// 严格翻译自: src/install_jsc/update_request_jsc.zig
//! JSC bridge for `bun.install.PackageManager.UpdateRequest`.
package bao_install_jsc

import bao_jsc.*
import bao_core.*

// ============================================================================
// UpdateRequestJSC - UpdateRequest 的 JSC 桥接
// 严格翻译自: src/install_jsc/update_request_jsc.zig:3-62
// ============================================================================

/// 从 JS 创建 UpdateRequest - 严格对应 Bun fromJS
/// Zig: pub fn fromJS(globalThis, input) bun.JSError!jsc.JSValue
public func updateRequestFromJS(globalThis: JSGlobalObject, input: JSValue): JSValue {
    let arena = ArenaAllocator(Allocator.default)
    let allocator = arena.allocator()
    var allPositionals = ArrayList<String>(allocator)

    let log = Logger.Log.init(allocator)

    if (input.isString) {
        let inputStr = input.toSliceCloneWithAllocator(globalThis, allocator)
        if (inputStr.size > 0) {
            allPositionals.append(inputStr.slice())
        }
    } else if (input.isArray) {
        var iter = input.arrayIterator(globalThis)
        while (let item = iter.next()) {
            let slice = item.toSliceCloneWithAllocator(globalThis, allocator)
            if (slice.size == 0) {
                continue
            }
            allPositionals.append(slice.slice())
        }
    } else {
        return JSValue.jsUndefined
    }

    if (allPositionals.size == 0) {
        return JSValue.jsUndefined
    }

    var array = UpdateRequestArray()

    let updateRequests = UpdateRequest.parseWithError(allocator, None, log, allPositionals.items, array, .add, false)
    if (updateRequests.isErr) {
        globalThis.throwValue(log.toJS(globalThis, Allocator.default, "Failed to parse dependencies"))
        return JSValue.zero
    }
    if (updateRequests.resultValue.size == 0) {
        return JSValue.jsUndefined
    }

    if (log.msgs.size > 0) {
        globalThis.throwValue(log.toJS(globalThis, Allocator.default, "Failed to parse dependencies"))
        return JSValue.zero
    }

    if (updateRequests.resultValue[0].failed) {
        globalThis.throw("Failed to parse dependencies")
        return JSValue.zero
    }

    let object = JSValue.createEmptyObject(globalThis, 2)
    let nameStr = BaoString.init(updateRequests.resultValue[0].name)
    object.put(globalThis, "name", nameStr.transferToJS(globalThis))
    object.put(globalThis, "version", updateRequests.resultValue[0].version.toJS(updateRequests.resultValue[0].versionBuf, globalThis))
    return object
}
