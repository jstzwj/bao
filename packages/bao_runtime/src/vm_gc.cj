// bao_runtime vm_gc - 垃圾回收器
// 严格翻译自: src/runtime/ garbage collection
// 参考: JavaScriptCore (JSC) 的 GC 实现 (Heap/MarkedSpace/HandleSet)
//   JSC 使用分代垃圾回收 (Eden + Survivor + OldGen):
//   - 快速的 Eden GC (只扫描新分配的对象)
//   - 全量的 Full GC (标记-清除)
//   - Write barrier 维护分代间引用
//   Bun 继承 JSC 的 GC 管理所有 JS 值的生命周期
//   仓颉没有内置 GC API，因此实现简化版的 mark-and-sweep GC
package bao_runtime

import bao_core.*
import bao_collections.*

// ============================================================================
// GcColor - GC 标记颜色
// 对应 JSC: tri-color marking (white/gray/black)
//   JSC 使用三色标记法:
//   - White: 未访问 (潜在的垃圾)
//   - Gray: 已发现但子节点未扫描
//   - Black: 已完全扫描 (存活)
// ============================================================================

/// GC 标记颜色 - 对应 JSC 三色标记法
public enum GcColor {
    | White   // 未标记 (可能是垃圾)
    | Gray    // 已标记但子节点未扫描
    | Black   // 已完全扫描，确认存活
}

// ============================================================================
// HeapObject - 堆对象
// 对应 JSC: JSCell (所有 GC 管理的对象基类)
//   JSCell { Structure*, cellState (white/gray/black), ... }
//   每个 JS 对象在 JSC 堆上都是一个 JSCell
//   仓颉 HeapObject 包装 JsValue，增加 GC 元数据
// ============================================================================

/// 堆对象 - 对应 JSC JSCell
/// GC 管理的基本单位
public class HeapObject {
    /// 唯一 ID
    public let id: Int64
    /// GC 标记颜色
    public var color: GcColor
    /// 引用计数 (用于快速回收循环引用之外的场景)
    public var refCount: Int64
    /// 包裹的 JS 值
    public var value: JsValue
    /// 子引用 (此对象引用的其他 HeapObject)
    public var references: ArrayList<Int64>  // 引用的 HeapObject ID 列表
    /// 是否已在待扫描队列中
    public var inQueue: Bool
    /// 分代 (0 = 新生代, 1 = 老生代)
    public var generation: Int64
    /// 是否已被最终化
    public var finalized: Bool

    private static var nextId: Int64 = 1

    public init(value: JsValue) {
        this.id = HeapObject.nextId
        HeapObject.nextId += 1
        this.color = GcColor.White
        this.refCount = 0
        this.value = value
        this.references = ArrayList<Int64>()
        this.inQueue = false
        this.generation = 0
        this.finalized = false
    }

    /// 添加引用
    public func addReference(targetId: Int64): Unit {
        references.append(targetId)
    }

    /// 移除引用
    public func removeReference(targetId: Int64): Unit {
        let newArr = ArrayList<Int64>()
        for (ref in references) {
            if (ref != targetId) {
                newArr.append(ref)
            }
        }
        references = newArr
    }

    /// 标记为灰色
    public func markGray(): Unit {
        if (color == GcColor.White) {
            color = GcColor.Gray
        }
    }

    /// 标记为黑色
    public func markBlack(): Unit {
        color = GcColor.Black
    }

    /// 重置为白色 (GC 周期开始时)
    public func resetWhite(): Unit {
        color = GcColor.White
        inQueue = false
    }

    /// 增加引用计数
    public func retain(): Unit {
        refCount += 1
    }

    /// 减少引用计数
    public func release(): Unit {
        refCount -= 1
    }

    /// 是否存活 (被引用或已被标记)
    public func isLive(): Bool {
        return refCount > 0 || color != GcColor.White
    }

    /// 晋升到老生代
    public func promote(): Unit {
        generation = 1
    }
}

// ============================================================================
// GcRoot - GC 根
// 对应 JSC: GC roots (全局对象、栈帧、Handle 等)
//   GC 从 roots 出发，沿引用链标记所有可达对象
//   不可达的对象被回收
// ============================================================================

/// GC 根类型
public enum GcRootKind {
    | GlobalScope   // 全局作用域
    | CallStack     // 调用栈帧
    | Register      // 寄存器
    | Handle        // 外部 Handle (持久引用)
    | Cache         // 内联缓存等
}

/// GC 根条目
public class GcRoot {
    /// 根类型
    public var kind: GcRootKind
    /// 指向的 HeapObject ID
    public var objectId: Int64
    /// 描述信息 (用于调试)
    public var description: String

    public init(kind: GcRootKind, objectId: Int64, description: String) {
        this.kind = kind
        this.objectId = objectId
        this.description = description
    }
}

// ============================================================================
// GcStats - GC 统计信息
// 对应 JSC: GCIncomingRefs / HeapStatistics
// ============================================================================

/// GC 统计信息
public class GcStats {
    /// 总堆大小 (对象数)
    public var heapSize: Int64
    /// 存活对象数
    public var liveObjects: Int64
    /// 已回收对象数
    public var collectedObjects: Int64
    /// GC 执行次数
    public var gcCount: Int64
    /// 标记耗时 (纳秒)
    public var markTimeNs: Int64
    /// 清除耗时 (纳秒)
    public var sweepTimeNs: Int64
    /// 新生代对象数
    public var youngGenSize: Int64
    /// 老生代对象数
    public var oldGenSize: Int64

    public init() {
        heapSize = 0
        liveObjects = 0
        collectedObjects = 0
        gcCount = 0
        markTimeNs = 0
        sweepTimeNs = 0
        youngGenSize = 0
        oldGenSize = 0
    }

    /// 生成统计报告
    public func report(): String {
        return "GC Stats: heap=${heapSize} live=${liveObjects} " +
               "collected=${collectedObjects} gcCount=${gcCount} " +
               "young=${youngGenSize} old=${oldGenSize}"
    }
}

// ============================================================================
// GarbageCollector - 标记-清除垃圾回收器
// 严格翻译自: JSC Heap::collect (mark-and-sweep)
//   JSC GC 流程:
//   1. Stop-the-world (暂停所有 mutator 线程)
//   2. Mark: 从 roots 出发，三色标记所有可达对象
//   3. Sweep: 遍历堆，回收所有白色 (不可达) 对象
//   4. Compact: 可选的内存压缩 (消除碎片)
//   5. Resume mutator
//   仓颉实现简化版:
//   - 引用计数 + 定期标记-清除处理循环引用
//   - 新生代/老生代分代 (简化)
// ============================================================================

/// 垃圾回收器 - 对应 JSC Heap
/// 管理所有 HeapObject 的生命周期
public class GarbageCollector {
    /// 堆: 所有分配的对象 (ID -> HeapObject)
    private var heap: HashMap<Int64, HeapObject>
    /// GC 根集合
    private var roots: ArrayList<GcRoot>
    /// 灰色队列 (待扫描) - 对应 JSC mark stack
    private var grayQueue: ArrayList<Int64>
    /// 统计信息
    private var stats: GcStats
    /// GC 阈值: 当堆大小超过此值时触发 GC
    private var gcThreshold: Int64
    /// 新生代最大存活次数 (经过此次 GC 后晋升到老生代)
    private var promotionThreshold: Int64
    /// 是否正在执行 GC
    private var collecting: Bool
    /// 全局环境引用 (作为 root)
    private var globalEnv: ?Environment
    /// 寄存器引用 (作为 root)
    private var registers: ?Array<JsValue>

    public init() {
        heap = HashMap<Int64, HeapObject>()
        roots = ArrayList<GcRoot>()
        grayQueue = ArrayList<Int64>()
        stats = GcStats()
        gcThreshold = 1024  // 默认阈值: 1024 个对象
        promotionThreshold = 3  // 经过 3 次 GC 存活后晋升
        collecting = false
        globalEnv = None
        registers = None
    }

    // ========================================================================
    // 对象分配
    // 对应 JSC: Heap::allocate / CellContainer
    // ========================================================================

    /// 在堆上分配对象
    /// 对应 JSC Heap::allocateObjectOfType
    public func allocate(value: JsValue): HeapObject {
        let obj = HeapObject(value)
        heap.put(obj.id, obj)
        stats.heapSize = heap.keys().size

        // 检查是否需要触发 GC
        if (stats.heapSize > gcThreshold && !collecting) {
            collect()
        }

        return obj
    }

    /// 获取堆对象
    public func get(id: Int64): ?HeapObject {
        return heap.get(id)
    }

    // ========================================================================
    // GC 根管理
    // 对应 JSC: RootMarkReason / SlotVisitor
    // ========================================================================

    /// 注册 GC 根
    public func addRoot(kind: GcRootKind, objectId: Int64, description: String): Unit {
        roots.append(GcRoot(kind, objectId, description))
    }

    /// 移除 GC 根
    public func removeRoot(objectId: Int64): Unit {
        let newRoots = ArrayList<GcRoot>()
        for (root in roots) {
            if (root.objectId != objectId) {
                newRoots.append(root)
            }
        }
        roots = newRoots
    }

    /// 设置全局环境根
    public func setGlobalEnv(env: Environment): Unit {
        globalEnv = Some(env)
    }

    /// 设置寄存器文件根
    public func setRegisters(regs: Array<JsValue>): Unit {
        registers = Some(regs)
    }

    // ========================================================================
    // 引用计数
    // 对应 JSC: ref-counted GC handles
    //   引用计数用于快速回收无循环引用的对象
    //   循环引用需要 mark-and-sweep 处理
    // ========================================================================

    /// 增加引用
    public func retain(id: Int64): Unit {
        match (heap.get(id)) {
            case Some(obj) => obj.retain()
            case None => ()
        }
    }

    /// 减少引用
    public func release(id: Int64): Unit {
        match (heap.get(id)) {
            case Some(obj) => {
                obj.release()
                // 引用计数归零: 如果不是循环引用，可以立即回收
                // 但保守起见，交给 mark-and-sweep 处理
            }
            case None => ()
        }
    }

    /// 记录引用关系 (from -> to)
    /// 对应 JSC 的 write barrier: 记录老生代到新生代的引用
    public func addReference(fromId: Int64, toId: Int64): Unit {
        match (heap.get(fromId)) {
            case Some(from) => from.addReference(toId)
            case None => ()
        }
    }

    /// 移除引用关系
    public func removeReference(fromId: Int64, toId: Int64): Unit {
        match (heap.get(fromId)) {
            case Some(from) => from.removeReference(toId)
            case None => ()
        }
    }

    // ========================================================================
    // 标记-清除 GC
    // 严格翻译自: JSC Heap::collect
    //   1. markRoots(): 从所有 GC 根开始标记
    //   2. markLoop(): 处理灰色队列 (BFS)
    //   3. sweep(): 回收白色对象
    //   4. finalize(): 清理已回收对象的资源
    // ========================================================================

    /// 执行垃圾回收
    /// 对应 JSC Heap::collect (slotVisitor, heapSnapshot, etc.)
    public func collect(): GcStats {
        if (collecting) {
            return stats  // 防止重入
        }
        collecting = true
        stats.gcCount += 1

        // === 阶段 1: 重置所有对象为白色 ===
        // 对应 JSC Heap::resetHeapConsistencyCheck
        resetMarks()

        // === 阶段 2: 标记根 ===
        // 对应 JSC SlotVisitor::appendRoots
        markRoots()

        // === 阶段 3: 处理灰色队列 ===
        // 对应 JSC SlotVisitor::drainMarkStack
        processGrayQueue()

        // === 阶段 4: 清除 ===
        // 对应 JSC MarkedSpace::sweep
        sweep()

        // === 阶段 5: 晋升存活对象 ===
        promoteSurvivors()

        // === 阶段 6: 调整 GC 阈值 ===
        adjustThreshold()

        collecting = false
        return stats
    }

    /// 重置所有标记为白色
    private func resetMarks(): Unit {
        for (key in heap.keys()) {
            match (heap.get(key)) {
                case Some(obj) => obj.resetWhite()
                case None => ()
            }
        }
        grayQueue = ArrayList<Int64>()
    }

    /// 标记根对象
    /// 对应 JSC Heap::markRoots
    /// 从 GC 根集合开始，将所有直接可达对象标记为灰色
    private func markRoots(): Unit {
        // 1. 显式 GC 根
        for (root in roots) {
            match (heap.get(root.objectId)) {
                case Some(obj) => {
                    obj.markGray()
                    if (!obj.inQueue) {
                        grayQueue.append(obj.id)
                        obj.inQueue = true
                    }
                }
                case None => ()
            }
        }

        // 2. 全局作用域中的变量
        // 对应 JSC: JSGlobalObject 的属性
        match (globalEnv) {
            case Some(env) => markEnvironment(env)
            case None => ()
        }

        // 3. 寄存器文件
        // 对应 JSC: ExecState 中的寄存器
        match (registers) {
            case Some(regs) => {
                for (i in 0..regs.size) {
                    markJsValue(regs[i])
                }
            }
            case None => ()
        }
    }

    /// 标记环境中的所有绑定
    private func markEnvironment(env: Environment): Unit {
        // 标记环境中的所有值
        for (key in env.bindings.keys()) {
            match (env.bindings.get(key)) {
                case Some(binding) => markJsValue(binding.value)
                case None => ()
            }
        }
        // 递归标记父作用域
        match (env.parent) {
            case Some(parent) => markEnvironment(parent)
            case None => ()
        }
    }

    /// 标记单个 JsValue
    private func markJsValue(value: JsValue): Unit {
        // 对象和数组需要标记
        if (value.valueType == JsValueType.Object) {
            match (value.objectData) {
                case Some(obj) => {
                    for (key in obj.keys()) {
                        match (obj.get(key)) {
                            case Some(v) => markJsValue(v)
                            case None => ()
                        }
                    }
                }
                case None => ()
            }
        }
        if (value.valueType == JsValueType.Array) {
            match (value.arrayData) {
                case Some(arr) => {
                    for (item in arr) {
                        markJsValue(item)
                    }
                }
                case None => ()
            }
        }
        if (value.valueType == JsValueType.Function) {
            match (value.functionData) {
                case Some(fn) => {
                    // 标记闭包环境
                    markEnvironment(fn.closure)
                }
                case None => ()
            }
        }
    }

    /// 处理灰色队列 (BFS 标记)
    /// 对应 JSC SlotVisitor::drainMarkStack
    /// 将灰色对象变为黑色，并将其引用的白色对象标记为灰色
    private func processGrayQueue(): Unit {
        while (grayQueue.size > 0) {
            // 出队
            let objId = grayQueue[0]
            grayQueue.removeAt(0)

            match (heap.get(objId)) {
                case Some(obj) => {
                    // 标记为黑色
                    obj.markBlack()

                    // 处理子引用
                    for (refId in obj.references) {
                        match (heap.get(refId)) {
                            case Some(ref) => {
                                if (ref.color == GcColor.White && !ref.inQueue) {
                                    ref.markGray()
                                    grayQueue.append(ref.id)
                                    ref.inQueue = true
                                }
                            }
                            case None => ()
                        }
                    }

                    // 处理 JsValue 内部引用
                    markJsValueChildren(obj)
                }
                case None => ()
            }
        }
    }

    /// 标记 JsValue 内部的子引用
    private func markJsValueChildren(obj: HeapObject): Unit {
        let value = obj.value
        if (value.valueType == JsValueType.Object) {
            match (value.objectData) {
                case Some(objData) => {
                    for (key in objData.keys()) {
                        match (objData.get(key)) {
                            case Some(v) => markJsValue(v)
                            case None => ()
                        }
                    }
                }
                case None => ()
            }
        }
        if (value.valueType == JsValueType.Array) {
            match (value.arrayData) {
                case Some(arr) => {
                    for (item in arr) {
                        markJsValue(item)
                    }
                }
                case None => ()
            }
        }
    }

    /// 清除不可达对象
    /// 对应 JSC MarkedSpace::sweep
    /// 遍历堆，回收所有仍为白色的对象 (不可达)
    private func sweep(): Unit {
        let toRemove = ArrayList<Int64>()
        var liveCount: Int64 = 0
        var youngCount: Int64 = 0
        var oldCount: Int64 = 0

        for (key in heap.keys()) {
            match (heap.get(key)) {
                case Some(obj) => {
                    if (obj.color == GcColor.White) {
                        // 不可达对象 - 回收
                        finalizeObject(obj)
                        toRemove.append(key)
                    } else {
                        // 存活
                        liveCount += 1
                        if (obj.generation == 0) {
                            youngCount += 1
                        } else {
                            oldCount += 1
                        }
                    }
                }
                case None => ()
            }
        }

        // 从堆中移除
        for (id in toRemove) {
            heap.remove(id)
        }

        stats.collectedObjects = toRemove.size
        stats.liveObjects = liveCount
        stats.heapSize = heap.keys().size
        stats.youngGenSize = youngCount
        stats.oldGenSize = oldCount
    }

    /// 最终化对象 (释放资源)
    /// 对应 JSC: JSObject::finalize
    private func finalizeObject(obj: HeapObject): Unit {
        if (obj.finalized) {
            return
        }
        obj.finalized = true

        // 清理引用关系
        obj.references = ArrayList<Int64>()

        // 清理 JsValue 内部数据
        match (obj.value.objectData) {
            case Some(objData) => {
                // 清除对象属性引用
                for (key in objData.keys()) {
                    objData.delete(key)
                }
            }
            case None => ()
        }

        match (obj.value.arrayData) {
            case Some(arr) => {
                // 清除数组引用
                for (i in 0..arr.size) {
                    arr[i] = JsValue.UNDEFINED
                }
            }
            case None => ()
        }
    }

    /// 晋升存活的新生代对象到老生代
    /// 对应 JSC: EdenGC 中的晋升逻辑
    private func promoteSurvivors(): Unit {
        for (key in heap.keys()) {
            match (heap.get(key)) {
                case Some(obj) => {
                    if (obj.generation == 0 && obj.color == GcColor.Black) {
                        // 新生代对象在 GC 中存活，增加存活计数
                        // 简化: 直接晋升
                        obj.promote()
                    }
                }
                case None => ()
            }
        }
    }

    /// 调整 GC 阈值
    /// 对应 JSC: Heap::updateAllocationLimits
    private func adjustThreshold(): Unit {
        // 动态调整阈值: 根据存活对象数量
        let newThreshold = stats.liveObjects * 2
        if (newThreshold > gcThreshold) {
            gcThreshold = newThreshold
        }
        // 设置最小阈值
        if (gcThreshold < 256) {
            gcThreshold = 256
        }
    }

    // ========================================================================
    // 公共接口
    // ========================================================================

    /// 获取堆大小
    public func heapSize(): Int64 {
        return heap.keys().size
    }

    /// 获取统计信息
    public func getStats(): GcStats {
        return stats
    }

    /// 手动触发 GC
    public func forceCollect(): GcStats {
        return collect()
    }

    /// 设置 GC 阈值
    public func setThreshold(threshold: Int64): Unit {
        gcThreshold = threshold
    }

    /// 检查是否有循环引用
    /// 使用 DFS 检测引用图中是否存在环
    public func detectCycles(): ArrayList<ArrayList<Int64>> {
        let cycles = ArrayList<ArrayList<Int64>>()
        let visited = HashMap<Int64, Bool>()
        let onStack = HashMap<Int64, Bool>()

        for (key in heap.keys()) {
            match (heap.get(key)) {
                case Some(obj) => {
                    let path = ArrayList<Int64>()
                    dfs(key, visited, onStack, path, cycles)
                }
                case None => ()
            }
        }

        return cycles
    }

    /// DFS 检测环
    private func dfs(id: Int64, visited: HashMap<Int64, Bool>,
                      onStack: HashMap<Int64, Bool>,
                      path: ArrayList<Int64>,
                      cycles: ArrayList<ArrayList<Int64>>): Unit {
        // 已访问过
        match (visited.get(id)) {
            case Some(true) => ()
            case _ => ()
        }

        visited.put(id, true)
        onStack.put(id, true)
        path.append(id)

        match (heap.get(id)) {
            case Some(obj) => {
                for (refId in obj.references) {
                    match (onStack.get(refId)) {
                        case Some(true) => {
                            // 找到环: 从 path 中提取
                            let cycle = ArrayList<Int64>()
                            var found = false
                            for (nodeId in path) {
                                if (nodeId == refId) { found = true }
                                if (found) { cycle.append(nodeId) }
                            }
                            if (cycle.size > 0) {
                                cycles.append(cycle)
                            }
                        }
                        case _ => {
                            dfs(refId, visited, onStack, path, cycles)
                        }
                    }
                }
            }
            case None => ()
        }

        path.removeAt(path.size - 1)
        onStack.put(id, false)
    }

    /// 销毁 GC，释放所有资源
    public func destroy(): Unit {
        for (key in heap.keys()) {
            match (heap.get(key)) {
                case Some(obj) => finalizeObject(obj)
                case None => ()
            }
        }
        heap = HashMap<Int64, HeapObject>()
        roots = ArrayList<GcRoot>()
        grayQueue = ArrayList<Int64>()
        stats = GcStats()
    }
}
