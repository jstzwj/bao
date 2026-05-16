// 严格翻译自: src/ptr/ptr.zig
// ptr 模块 - 包含 Bun 中使用的智能指针类型
package bao_ptr

import bao_core.*
// 同包内的所有类型自动可见，无需 import

// ============================================================================
// 公开导出的类型别名 (对应 ptr.zig 中的 pub const)
// ============================================================================

/// Copy-on-Write 类型
/// 对应: pub const Cow = @import("./Cow.zig").Cow;
public type CowAlias<T> = Cow<T>

/// Copy-on-Write 切片
/// 对应: pub const CowSlice = @import("./CowSlice.zig").CowSlice;
public type CowSliceAlias<T> = CowSlice<T>

/// Copy-on-Write 字符串
/// 对应: pub const CowString = CowSlice(u8);
public type CowStringAlias = CowSlice<Byte>

/// 所有权指针 (使用默认分配器)
/// 对应: pub const Owned = owned.Owned;
public type OwnedAlias<T> = Owned<T>

/// 所有权指针 (使用特定分配器)
/// 对应: pub const OwnedIn = owned.OwnedIn;
public type OwnedInAlias<T> = OwnedIn<T>

/// 所有权指针 (使用任意分配器)
/// 对应: pub const DynamicOwned = owned.Dynamic;
public type DynamicOwnedAlias<T> = Dynamic<T>

/// 共享指针
/// 对应: pub const Shared = shared.Shared;
public type SharedAlias<T> = Shared<T>

/// 线程安全共享指针
/// 对应: pub const AtomicShared = shared.AtomicShared;
public type AtomicSharedAlias<T> = AtomicShared<T>

/// 外部管理的共享指针
/// 对应: pub const ExternalShared = @import("./external_shared.zig").ExternalShared;
public type ExternalSharedAlias<T> = ExternalShared<T>

/// 引用计数 (已弃用，建议使用 Shared)
/// 对应: pub const RefCount = ref_count.RefCount;
public type RefCountAlias = RefCount

/// 线程安全引用计数 (已弃用，建议使用 AtomicShared)
/// 对应: pub const ThreadSafeRefCount = ref_count.ThreadSafeRefCount;
public type ThreadSafeRefCountAlias = ThreadSafeRefCount

/// 引用计数指针 (已弃用，建议使用 Shared)
/// 对应: pub const RefPtr = ref_count.RefPtr;
public type RefPtrAlias<T> = RefPtr<T>

/// 原始引用计数
/// 对应: pub const RawRefCount = raw_ref_count.RawRefCount;
public type RawRefCountAlias = RawRefCount

/// 标记指针
/// 对应: pub const TaggedPointer = @import("./tagged_pointer.zig").TaggedPointer;
public type TaggedPointerAlias = TaggedPointer

/// 标记指针联合体
/// 对应: pub const TaggedPointerUnion = @import("./tagged_pointer.zig").TaggedPointerUnion;
public type TaggedPointerUnionAlias = TaggedPointerUnion

/// 弱指针 (已弃用，建议使用 Shared.Weak)
/// 对应: pub const WeakPtr = @import("./weak_ptr.zig").WeakPtr;
public type WeakPtrAlias<T> = WeakPtr<T>

/// 非拥有反向引用 (不可变父对象)
/// 对应: lib.rs 中的 BackRef<T>
public type BackRefAlias<T> = BackRef<T>

/// 非拥有反向引用 (可变父对象，debug 活性检查)
/// 对应: pub use parent_ref::{Anchored, LiveMarker, ParentRef};
public type ParentRefAlias<T> = ParentRef<T>

/// 活性标记哨兵
/// 对应: pub use parent_ref::LiveMarker;
public type LiveMarkerAlias = LiveMarker

/// 回调分发 self 指针
/// 对应: lib.rs 中的 ThisPtr<T>
public type ThisPtrAlias<T> = ThisPtr<T>

/// 进程生命周期字节切片证明类型
/// 对应: lib.rs 中的 Interned
public type InternedAlias = Interned
