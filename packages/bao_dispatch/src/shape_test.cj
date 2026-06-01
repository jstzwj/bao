// 严格翻译自: src/dispatch/tests/shape.rs
// dispatch link_interface 示例测试的仓颉等价实现

package bao_dispatch

// ============================================================================
// Shape 测试接口 - 验证 dispatch 机制
// 严格翻译自: shape.rs:4-11
//   bun_dispatch::link_interface! {
//       pub Shape[Circle, Square] {
//           fn area() -> f64;
//           fn scale(k: f64);
//           fn name() -> &'static str;
//           fn label(prefix: &str, out: &mut String);
//       }
//   }
// ============================================================================

/// 形状种类 - 对应 Shape[Circle, Square] 的 Kind 枚举
public enum ShapeKind {
    | Circle
    | Square

    public operator func == (rhs: ShapeKind): Bool {
        match (this) {
            case Circle => match (rhs) { case Circle => true; case _ => false }
            case Square => match (rhs) { case Square => true; case _ => false }
        }
    }
    public operator func != (rhs: ShapeKind): Bool {
        !(this == rhs)
    }
}

/// 形状分发句柄 - 对应 link_interface! 生成的 Shape handle
public class ShapeHandle {
    public var kind: ShapeKind
    public var owner: CPointer<Unit>

    public init() {
        this.kind = ShapeKind.Circle
        this.owner = CPointer<Unit>()
    }

    public static func new(kind: ShapeKind, owner: CPointer<Unit>): ShapeHandle {
        let h = ShapeHandle()
        h.kind = kind
        h.owner = owner
        return h
    }

    public func is(kind: ShapeKind): Bool {
        this.kind == kind
    }
}

/// 圆形实现
// 严格翻译自: shape.rs:13-15
//   pub(crate) struct CircleT { r: f64 }
public class CircleT {
    public var r: Float64

    public init() {
        this.r = 0.0
    }

    public init(r: Float64) {
        this.r = r
    }

    /// 计算面积
    public func area(): Float64 {
        return Float64.pi * r * r
    }

    /// 缩放
    public func scale(k: Float64): Unit {
        r *= k
    }

    /// 名称
    public func name(): String {
        "circle"
    }

    /// 标签
    public func label(prefix: String): String {
        return "${prefix}circle"
    }
}

/// 正方形实现
// 严格翻译自: shape.rs:16-18
//   pub(crate) struct SquareT { s: f64 }
public class SquareT {
    public var s: Float64

    public init() {
        this.s = 0.0
    }

    public init(s: Float64) {
        this.s = s
    }

    /// 计算面积
    public func area(): Float64 {
        return s * s
    }

    /// 缩放
    public func scale(k: Float64): Unit {
        s *= k
    }

    /// 名称
    public func name(): String {
        "square"
    }

    /// 标签
    public func label(prefix: String): String {
        return "${prefix}square"
    }
}

/// 形状分发器 - 执行 match kind { ... } 分发
/// 对应 link_interface! 生成的分发方法
public class ShapeDispatch {
    /// 分发 area() 调用
    public static func area(handle: ShapeHandle): Float64 {
        match (handle.kind) {
            case ShapeKind.Circle =>
                let circle = CircleT.handleFrom(handle.owner)
                return circle.area()
            case ShapeKind.Square =>
                let square = SquareT.handleFrom(handle.owner)
                return square.area()
        }
    }

    /// 分发 scale() 调用
    public static func scale(handle: ShapeHandle, k: Float64): Unit {
        match (handle.kind) {
            case ShapeKind.Circle =>
                let circle = CircleT.handleFrom(handle.owner)
                circle.scale(k)
            case ShapeKind.Square =>
                let square = SquareT.handleFrom(handle.owner)
                square.scale(k)
        }
    }

    /// 分发 name() 调用
    public static func name(handle: ShapeHandle): String {
        match (handle.kind) {
            case ShapeKind.Circle =>
                let circle = CircleT.handleFrom(handle.owner)
                return circle.name()
            case ShapeKind.Square =>
                let square = SquareT.handleFrom(handle.owner)
                return square.name()
        }
    }

    /// 分发 label() 调用
    public static func label(handle: ShapeHandle, prefix: String, buf: StringBuilder): Unit {
        match (handle.kind) {
            case ShapeKind.Circle =>
                let circle = CircleT.handleFrom(handle.owner)
                buf.append(circle.label(prefix))
            case ShapeKind.Square =>
                let square = SquareT.handleFrom(handle.owner)
                buf.append(square.label(prefix))
        }
    }
}
