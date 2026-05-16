// bao_threading - RwLock 读写锁 (原子状态机实现)
// 严格翻译自:
//   src/threading/RwLock.rs - RwLock<T> (RawRwLock + data-owning wrapper)
//   Zig std.Thread.RwLock.DefaultRwLock (Zig 0.14.1)
//
// Bun 的 RawRwLock 使用原子状态机 (AtomicUsize):
//   bit 0                : IS_WRITING — 写锁持有标志
//   bits 1..=COUNT_BITS  : pending-writer count (WRITER_MASK)
//   bits COUNT_BITS+1..  : active-reader  count (READER_MASK)
//
//   COUNT_BITS = floor((usize::BITS - 1) / 2)
//   64位平台: COUNT_BITS = 31, 每种计数最大 2^31-1
//   32位平台: COUNT_BITS = 15, 每种计数最大 2^15-1
//
// 仓颉使用 AtomicInt64 实现等价的位操作状态机
package bao_threading

import std.sync.*
import std.collection.ArrayList
import std.time.*

// ============================================================================
// 常量定义 - 对应 Bun RwLock.rs:30-51 位布局常量
// 严格翻译自: RwLock.rs COUNT_BITS/IS_WRITING/WRITER/READER/WRITER_MASK/READER_MASK
//
// 64位平台:
//   COUNT_BITS = 31
//   COUNT_MAX  = 0x7FFFFFFF (2^31 - 1)
//   IS_WRITING = 1              (bit 0)
//   WRITER     = 1 << 1 = 2     (bit 1)
//   READER     = 1 << 32        (bit 32)
//   WRITER_MASK = COUNT_MAX << 1 = 0xFFFFFFFE
//   READER_MASK = COUNT_MAX << 32 = 0x7FFFFFFF00000000
// ============================================================================

/// COUNT_BITS: floor((64 - 1) / 2) = 31
/// 严格翻译自: RwLock.rs:44 const COUNT_BITS: u32 = (usize::BITS - 1) / 2
private let COUNT_BITS: Int64 = 31

/// COUNT_MAX: (1 << COUNT_BITS) - 1 = 0x7FFFFFFF
/// 严格翻译自: RwLock.rs:45 const COUNT_MAX: usize = (1usize << COUNT_BITS) - 1
private let COUNT_MAX: Int64 = (Int64(1) << COUNT_BITS) - 1

/// IS_WRITING: bit 0 — 写锁持有标志
/// 严格翻译自: RwLock.rs:47 const IS_WRITING: usize = 1
private let IS_WRITING: Int64 = 1

/// WRITER: bit 1 — 等待写者计数单位
/// 严格翻译自: RwLock.rs:48 const WRITER: usize = 1 << 1
private let WRITER: Int64 = Int64(1) << 1

/// READER: bit (1 + COUNT_BITS) = bit 32 — 活跃读者计数单位
/// 严格翻译自: RwLock.rs:49 const READER: usize = 1 << (1 + COUNT_BITS)
private let READER: Int64 = Int64(1) << (1 + COUNT_BITS)

/// WRITER_MASK: 等待写者计数掩码
/// 严格翻译自: RwLock.rs:50 const WRITER_MASK: usize = COUNT_MAX << WRITER.trailing_zeros()
///   WRITER.trailing_zeros() = 1, 所以 WRITER_MASK = COUNT_MAX << 1
private let WRITER_MASK: Int64 = COUNT_MAX << 1

/// READER_MASK: 活跃读者计数掩码
/// 严格翻译自: RwLock.rs:51 const READER_MASK: usize = COUNT_MAX << READER.trailing_zeros()
///   READER.trailing_zeros() = 32, 所以 READER_MASK = COUNT_MAX << 32
private let READER_MASK: Int64 = COUNT_MAX << (1 + COUNT_BITS)

// ============================================================================
// RawRwLock - 原始读写锁状态机
// 严格翻译自: src/threading/RwLock.rs:30-144 RawRwLock
//
// Bun RawRwLock 使用 AtomicUsize state + Mutex + Semaphore:
//   state 的位布局:
//     bit 0                : IS_WRITING
//     bits 1..=COUNT_BITS  : pending-writer count
//     bits COUNT_BITS+1..  : active-reader count
//
//   try_lock: mutex.tryLock -> CAS state -> IS_WRITING
//   lock: fetchAdd(WRITER) -> mutex.lock -> fetchAdd(IS_WRITING - WRITER)
//         -> if readers > 0: semaphore.wait
//   unlock: fetchAnd(!IS_WRITING) -> mutex.unlock
//   try_lock_shared: CAS state + READER (无写者/等待写者时)
//                    或 mutex.tryLock -> fetchAdd(READER)
//   lock_shared: CAS state + READER 循环 -> mutex.lock -> fetchAdd(READER)
//   unlock_shared: fetchSub(READER) -> if last reader + writing: semaphore.post
// ============================================================================

/// 原始读写锁 - 对应 Bun RawRwLock
/// 严格翻译自: RwLock.rs:30-144
///
/// 状态机 (原子 state 的位布局):
///   bit 0:     IS_WRITING (写锁持有标志)
///   bits 1-31: pending-writer count (等待的写者数量)
///   bits 32-62: active-reader count (活跃的读者数量)
///
/// 写者优先: 有等待写者时阻止新读者
public class RawRwLock {
    /// 原子状态 - 对应 Bun state: AtomicUsize
    /// 严格翻译自: RwLock.rs:32 state: AtomicUsize
    private let state: AtomicInt64

    /// 互斥锁 - 对应 Bun mutex: Mutex
    /// 严格翻译自: RwLock.rs:33 mutex: Mutex
    private let mutex: Mutex

    /// 信号量 - 对应 Bun semaphore: Semaphore
    /// 用于写者等待所有读者退出
    /// 严格翻译自: RwLock.rs:34 semaphore: Semaphore
    private let semaphore: Semaphore

    public init() {
        state = AtomicInt64(Int64(0))
        mutex = Mutex()
        semaphore = Semaphore()
    }

    /// 尝试获取写锁 - 对应 Bun RawRwLock.try_lock()
    /// 严格翻译自: RwLock.rs:62-74
    ///
    /// Bun 实现:
    ///   if self.mutex.try_lock() {
    ///       let state = self.state.load(SeqCst)
    ///       if state & READER_MASK == 0 {
    ///           self.state.fetch_or(IS_WRITING, SeqCst)
    ///           return true
    ///       }
    ///       self.mutex.unlock()
    ///   }
    ///   return false
    public func tryLock(): Bool {
        if (mutex.tryLock()) {
            let s = state.load()
            // 严格对应 Bun: 只有在没有活跃读者时才能获取写锁
            if ((s & READER_MASK) == Int64(0)) {
                state.fetchOr(IS_WRITING)
                return true
            }
            mutex.unlock()
        }
        return false
    }

    /// 获取写锁 (阻塞) - 对应 Bun RawRwLock.lock()
    /// 严格翻译自: RwLock.rs:76-88
    ///
    /// Bun 实现:
    ///   state.fetch_add(WRITER, SeqCst)    // 增加等待写者计数
    ///   mutex.lock()                         // 获取互斥锁
    ///   // IS_WRITING - WRITER: 设置 IS_WRITING 位同时清除 WRITER 计数
    ///   state.fetch_add(IS_WRITING -% WRITER, SeqCst)
    ///   if state & READER_MASK != 0 {       // 如果有活跃读者
    ///       semaphore.wait()                 // 等待读者退出
    ///   }
    public func lock(): Unit {
        // 严格对应 Bun: 增加等待写者计数
        state.fetchAdd(WRITER)
        // 获取互斥锁
        mutex.lock()
        // 严格对应 Bun: IS_WRITING.wrapping_sub(WRITER)
        // 设置 IS_WRITING 位 (bit 0 = 1)，同时清除一个 WRITER 计数 (bit 1 减 1)
        // IS_WRITING - WRITER = 1 - 2 = -1 (wrapping)
        // fetchAdd(-1) 效果: 设置 bit 0 (IS_WRITING)，清除 bit 1 (WRITER 计数减一)
        let s = state.fetchAdd(IS_WRITING - WRITER)
        // 严格对应 Bun: if state & READER_MASK != 0
        if ((s & READER_MASK) != Int64(0)) {
            // 有活跃读者，等待信号量
            // 对应 Bun semaphore.wait()
            semaphore.acquire()
        }
    }

    /// 释放写锁 - 对应 Bun RawRwLock.unlock()
    /// 严格翻译自: RwLock.rs:90-93
    ///
    /// Bun 实现:
    ///   state.fetch_and(!IS_WRITING, SeqCst)  // 清除 IS_WRITING
    ///   mutex.unlock()                          // 释放互斥锁
    public func unlock(): Unit {
        // 严格对应 Bun: 清除 IS_WRITING 位
        state.fetchAnd(IS_WRITING ^ Int64(-1))
        // 释放互斥锁，允许等待的读者/写者竞争
        mutex.unlock()
    }

    /// 尝试获取读锁 - 对应 Bun RawRwLock.try_lock_shared()
    /// 严格翻译自: RwLock.rs:95-114
    ///
    /// Bun 实现:
    ///   let state = self.state.load(SeqCst)
    ///   if state & (IS_WRITING | WRITER_MASK) == 0 {
    ///       if CAS(state, state + READER) { return true }
    ///   }
    ///   if mutex.try_lock() {
    ///       state.fetch_add(READER, SeqCst)
    ///       mutex.unlock()
    ///       return true
    ///   }
    ///   return false
    public func tryLockShared(): Bool {
        let s = state.load()
        // 严格对应 Bun: 无活跃写者且无等待写者时，尝试 CAS
        if ((s & (IS_WRITING | WRITER_MASK)) == Int64(0)) {
            if (state.compareAndSwap(s, s + READER)) {
                return true
            }
        }
        // 严格对应 Bun: 回退到 mutex 路径
        // 有等待的写者或 CAS 失败，尝试通过 mutex 获取
        if (mutex.tryLock()) {
            state.fetchAdd(READER)
            mutex.unlock()
            return true
        }
        return false
    }

    /// 获取读锁 (阻塞) - 对应 Bun RawRwLock.lock_shared()
    /// 严格翻译自: RwLock.rs:117-135
    ///
    /// Bun 实现:
    ///   var state = self.state.load(SeqCst)
    ///   while state & (IS_WRITING | WRITER_MASK) == 0 {
    ///       match CAS_weak(state, state + READER) {
    ///           Ok(_) => return
    ///           Err(s) => state = s
    ///       }
    ///   }
    ///   // 有写者，走慢路径
    ///   mutex.lock()
    ///   state.fetch_add(READER, SeqCst)
    ///   mutex.unlock()
    public func lockShared(): Unit {
        var s = state.load()
        // 严格对应 Bun: 无写者时循环 CAS
        while ((s & (IS_WRITING | WRITER_MASK)) == Int64(0)) {
            if (state.compareAndSwap(s, s + READER)) {
                return
            }
            // CAS 失败，重新加载状态
            s = state.load()
        }
        // 严格对应 Bun: 有写者时走 mutex 慢路径
        mutex.lock()
        state.fetchAdd(READER)
        mutex.unlock()
    }

    /// 释放读锁 - 对应 Bun RawRwLock.unlock_shared()
    /// 严格翻译自: RwLock.rs:137-143
    ///
    /// Bun 实现:
    ///   let state = state.fetch_sub(READER, SeqCst)
    ///   // 如果这是最后一个读者且有写者在等待
    ///   if (state & READER_MASK == READER) && (state & IS_WRITING != 0) {
    ///       semaphore.post()  // 唤醒等待的写者
    ///   }
    public func unlockShared(): Unit {
        let s = state.fetchSub(READER)
        // 严格对应 Bun: state & READER_MASK == READER 表示这是最后一个读者
        // state & IS_WRITING != 0 表示有写者持有锁 (等待读者退出)
        if (((s & READER_MASK) == READER) && ((s & IS_WRITING) != Int64(0))) {
            // 唤醒等待的写者 - 对应 Bun semaphore.post()
            semaphore.release()
        }
    }

    /// 加载当前状态 (用于调试/测试)
    public func loadState(): Int64 {
        return state.load()
    }
}

// ============================================================================
// DataRwLock<T> - 数据持有型读写锁
// 严格翻译自: src/threading/RwLock.rs:149-236 RwLock<T>
//
// Bun RwLock<T>:
//   raw: RawRwLock
//   value: UnsafeCell<T>
//
//   read() -> RwLockReadGuard<'a, T>   (Deref<Target=T>)
//   write() -> RwLockWriteGuard<'a, T> (Deref + DerefMut)
//   try_read() -> Option<RwLockReadGuard>
//   try_write() -> Option<RwLockWriteGuard>
//   get_mut(&mut self) -> &mut T       (独占访问，无需锁)
//   into_inner(self) -> T              (消费锁，返回值)
//
// 仓颉没有 RAII guard + Drop 析构器，使用回调模式
// ============================================================================

/// 数据持有型读写锁 - 对应 Bun RwLock<T>
/// 严格翻译自: RwLock.rs:149-236
///
/// 包装 RawRwLock 和一个受保护的值 T:
///   read: 获取读锁，执行回调 (共享 &T)
///   write: 获取写锁，执行回调 (独占 &T)
///   tryRead/tryWrite: 非阻塞版本
public class DataRwLock<T> {
    /// 原始读写锁 - 对应 Bun raw: RawRwLock
    /// 严格翻译自: RwLock.rs:150 raw: RawRwLock
    private let raw: RawRwLock

    /// 受保护的值 - 对应 Bun value: UnsafeCell<T>
    /// 严格翻译自: RwLock.rs:151 value: UnsafeCell<T>
    private var value: T

    /// 初始化 - 对应 Bun RwLock::new(value)
    /// 严格翻译自: RwLock.rs:169 pub const fn new(value: T) -> Self
    public init(value: T) {
        raw = RawRwLock()
        this.value = value
    }

    /// 获取共享读锁并执行回调 - 对应 Bun RwLock.read()
    /// 严格翻译自: RwLock.rs:178-185
    ///   self.raw.lock_shared()
    ///   return RwLockReadGuard { lock: self, ... }
    ///   guard drop: self.lock.raw.unlock_shared()
    ///
    /// 仓颉没有 RAII guard，使用回调模式:
    ///   lockShared -> fn(value) -> unlockShared
    public func read<U>(fn: (T) -> U): U {
        raw.lockShared()
        try {
            return fn(value)
        } finally {
            raw.unlockShared()
        }
    }

    /// 获取独占写锁并执行回调 - 对应 Bun RwLock.write()
    /// 严格翻译自: RwLock.rs:188-195
    ///   self.raw.lock()
    ///   return RwLockWriteGuard { lock: self, ... }
    ///   guard drop: self.lock.raw.unlock()
    public func write<U>(fn: (T) -> U): U {
        raw.lock()
        try {
            return fn(value)
        } finally {
            raw.unlock()
        }
    }

    /// 非阻塞获取读锁并执行回调 - 对应 Bun RwLock.try_read()
    /// 严格翻译自: RwLock.rs:200-209
    ///   if self.raw.try_lock_shared() { Some(RwLockReadGuard { ... }) }
    ///   else { None }
    public func tryRead<U>(fn: (T) -> U): ?U {
        if (raw.tryLockShared()) {
            try {
                return Some(fn(value))
            } finally {
                raw.unlockShared()
            }
        }
        return None
    }

    /// 非阻塞获取写锁并执行回调 - 对应 Bun RwLock.try_write()
    /// 严格翻译自: RwLock.rs:213-222
    public func tryWrite<U>(fn: (T) -> U): ?U {
        if (raw.tryLock()) {
            try {
                return Some(fn(value))
            } finally {
                raw.unlock()
            }
        }
        return None
    }

    /// 获取内部值的可变引用 - 对应 Bun RwLock.get_mut()
    /// 严格翻译自: RwLock.rs:227-229
    ///   需要 &mut self (独占借用证明无其他线程持有锁)
    ///   返回直接可变访问
    public func getMut(): T {
        return value
    }

    /// 设置内部值 - 修改受保护的值 (必须在写锁保护下)
    public func set(newValue: T): Unit {
        value = newValue
    }

    /// 消费锁，返回内部值 - 对应 Bun RwLock.into_inner()
    /// 严格翻译自: RwLock.rs:233-235
    public func intoInner(): T {
        return value
    }
}
