# ArkTS 三方模块生成仓颉胶水代码的转换规则

## 顶层声明

| .d.ts    | 支持范围                                                     | 规格约束                                                     |
| -------- | ------------------------------------------------------------ | ------------------------------------------------------------ |
| 命名空间 | 无                                                           | 不支持                                                     |
| 全局函数 | 支持重载，支持泛型函数                                                     | |
| 全局变量 | 需要用户手动修改成正确的初始化值                             | 不支持泛型类型全局变量                                       |
| 接口     | 支持基本类型接口、可选属性、只读属性、成员函数、泛型、函数重载、数组类型、继承、嵌套对象 | 不支持索引签名、动态属性、函数类型、构造函数、声明合并 |
| 类型别名 | 支持枚举类型别名、class 类型别名、函数类型别名、联合类型别名  | 不支持对象字面量类型别名、命名空间中的类型的类型别名、交叉类型别名、泛型类型别名 |
| 类       | 支持构造函数、静态成员、私有成员、保护成员、私有属性、泛型成员、抽象类、类实现接口、继承类、重载方法 | 不支持待装饰器类、带命名空间的类型                           |
| 枚举     | 支持字符串枚举、数字枚举、常量枚举、异构枚举                 | 不支持计算值枚举。异构枚举中，枚举值会被统一转成字符串类型，需用户在使用时手动转换 |
| 导入     | 支持                                                           |                                                        |
| 导出     | 无                                                           | 不支持                                                       |

### 命名空间

目前不支持

### 全局函数

- 支持重载。
- 参数和返回值类型支持：基础类型、函数类型、tuple 类型、optional 类型、泛型函数。
- union 类型（参数是 union 类型会映射为多个类型重载）。

示例：

.d.ts 代码：

```typescript
declare function greeter(fn: (a: string) => void): void;
declare function printToConsole(s: string): void;
```

生成的仓颉代码：

```cangjie
import ohos.ark_interop.*
import ohos.ark_interop_helper.*
import ohos.base.*

/***********METHOD***********/
/**
* @brief greeter(fn: (a: string) => void): void
*/
public func greeter(fn: (a: String) -> Unit): Unit {
    hmsGlobalApiCall < Unit >( "_ark_interop_api", "greeter", { ctx =>[ctx.function({ ctx, info =>
            let p0 = String.fromJSValue(ctx, info[0])
            fn(p0)
            ctx.undefined().toJSValue()
        }).toJSValue()] })
}

/**
* @brief printToConsole(s: string): void
*/
public func printToConsole(s: String): Unit {
    hmsGlobalApiCall < Unit >( "_ark_interop_api", "printToConsole", { ctx =>[s.toJSValue(ctx)] })
}

```

泛型函数示例：

.d.ts 代码：

```typescript
declare function testMultiGenericT<T, M>(t: T, m: M): T;
```

生成的仓颉代码：

```cangjie
/**
  * @brief testMultiGenericT(t: T, m: M): T
  */
public func testMultiGenericT < T, M >(t: T, m: M): T where T <: JSInteropType<T>, M <: JSInteropType<M> {
    hmsGlobalApiCall < T >( "my_module_genericFunction", "testMultiGenericT", { ctx =>[t.toJSValue(ctx), m.toJSValue(ctx)] }) {
        ctx, info => T.fromJSValue(ctx, info)
    }
}

```

### 全局变量

- 由于全局变量声明不带初始值，所以生成的仓颉代码需要用户补全初始化值。

示例：

.d.ts 代码：

```typescript
declare var foo: number;
declare const goo: number;
declare let qoo: number;
```

生成的仓颉代码：

```cangjie
public const foo = !!!!!check in dts!!!!!

public const goo = !!!!!check in dts!!!!!

public const qoo = !!!!!check in dts!!!!!
```

### 接口

- 支持基本类型、可选属性、只读属性、成员函数、泛型、函数重载、数组类型。
- 不支持索引签名、继承、动态属性、嵌套对象、函数类型、构造函数、声明合并。

#### 基本类型

.d.ts 代码：

```typescript
interface GreetingSettings {
  greeting: string;
  duration?: number;
  color?: string;
}
```

生成的仓颉代码：

```cangjie
public class GreetingSettings {

    protected GreetingSettings(public var greeting: String,
    public var duration!: Option<Float64> = None,
    public var color!: Option<String> = None) {}


    public func toJSValue(context: JSContext): JSValue {
        let obj = context.object()
        obj["greeting"] = greeting.toJSValue(context)
        if(let Some(v) <- duration) {
            obj["duration"] = v.toJSValue(context)
        }
        if(let Some(v) <- color) {
            obj["color"] = v.toJSValue(context)
        }
        obj.toJSValue()
    }

    public static func fromJSValue (context: JSContext, input: JSValue): GreetingSettings {
        let obj = input.asObject()
        GreetingSettings(
        String.fromJSValue(context, obj["greeting"]),
        duration: if(obj["duration"].isUndefined()) {
            None
        } else {
            Float64.fromJSValue(context, obj["duration"])
        },
        color: if(obj["color"].isUndefined()) {
            None
        } else {
            String.fromJSValue(context, obj["color"])
        }
        )
    }

}
```

#### 可选属性

.d.ts 代码：

```typescript
// product.d.ts
interface Product {
  price?: number; // 可选属性
}
```

生成的仓颉代码：

```cangjie
public class Product {

    protected Product(public var price!: Option<Float64> = None) {}


    public func toJSValue(context: JSContext): JSValue {
        let obj = context.object()
        if(let Some(v) <- price) {
            obj["price"] = v.toJSValue(context)
        }
        obj.toJSValue()
    }

    public static func fromJSValue (context: JSContext, input: JSValue): Product {
        let obj = input.asObject()
        Product(
        price: if(obj["price"].isUndefined()) {
            None
        } else {
            Float64.fromJSValue(context, obj["price"])
        }
        )
    }

}
```

#### 只读属性

.d.ts 代码：

```typescript
// point.d.ts
interface Point {
  readonly x: number;
  readonly y: number;
}
```

生成的仓颉代码：

```cangjie
public class Point {

    protected Point(public let x: Float64,
    public let y: Float64) {}


    public func toJSValue(context: JSContext): JSValue {
        let obj = context.object()
        obj["x"] = x.toJSValue(context)
        obj["y"] = y.toJSValue(context)
        obj.toJSValue()
    }

    public static func fromJSValue (context: JSContext, input: JSValue): Point {
        let obj = input.asObject()
        Point(
        Float64.fromJSValue(context, obj["x"]),
        Float64.fromJSValue(context, obj["y"])
        )
    }

}
```

#### 函数类型

.d.ts 代码：

```typescript
// callback.d.ts
interface Callback {
  (data: string): void;
}
```

目前还不支持

#### 成员函数

.d.ts 代码：

```typescript
// person.d.ts
interface Person {
  name: string;
  greet(): string;
}
```

生成的仓颉代码：

```cangjie
public class Person {

    protected Person(let arkts_object: JSObject) {}


    public mut prop name: String {
        get() {
            checkThreadAndCall < String >(getMainContext()) {
                ctx: JSContext => String.fromJSValue(ctx, arkts_object["name"])
            }
        }
        set(v) {
            checkThreadAndCall < Unit >(getMainContext()) {
                ctx: JSContext => arkts_object["name"] = v.toJSValue(ctx)
            }
        }

    }

    /**
    * @brief greet(): String
    */
    public func greet(): String {
        jsObjApiCall < String >( arkts_object, "greet", emptyArg)
    }

    func toJSValue(context: JSContext): JSValue {
        arkts_object.toJSValue()
    }

    static func fromJSValue (context: JSContext, input: JSValue): Person {
        Person(input.asObject())
    }
}
```

#### 函数重载

.d.ts 代码：

```typescript
// calculator.d.ts
interface Calculator {
  add(x: number, y: number): number;
  add(x: string, y: string): string;
}
```

生成的仓颉代码：

```cangjie
public class Calculator {

    protected Calculator(let arkts_object: JSObject) {}


    /**
    * @brief add(x: number,y: number): number
    */
    public func add(x: Float64, y: Float64): Float64 {
        jsObjApiCall < Float64 >( arkts_object, "add", { ctx =>[x.toJSValue(ctx), y.toJSValue(ctx)] })
    }
    /**
    * @brief add(x: string,y: string): String
    */
    public func add(x: String, y: String): String {
        jsObjApiCall < String >( arkts_object, "add", { ctx =>[x.toJSValue(ctx), y.toJSValue(ctx)] })
    }

    func toJSValue(context: JSContext): JSValue {
        arkts_object.toJSValue()
    }

    static func fromJSValue (context: JSContext, input: JSValue): Calculator {
        Calculator(input.asObject())
    }
}
```

#### 数组类型

.d.ts 代码：

```typescript
// list.d.ts
interface List {
  items: string[];
  add(item: string): void;
}
```

生成的仓颉代码：

```cangjie
public class List {

    protected List(let arkts_object: JSObject) {}


    public mut prop items: Array<String> {
        get() {
            checkThreadAndCall < Array<String> >(getMainContext()) {
                ctx: JSContext => Array<String>.fromJSValue(ctx, arkts_object["items"])
            }
        }
        set(v) {
            checkThreadAndCall < Unit >(getMainContext()) {
                ctx: JSContext => arkts_object["items"] = v.toJSValue(ctx)
            }
        }

    }

    /**
    * @brief add(item: string): void
    */
    public func add(item: String): Unit {
        jsObjApiCall < Unit >( arkts_object, "add", { ctx =>[item.toJSValue(ctx)] })
    }

    func toJSValue(context: JSContext): JSValue {
        arkts_object.toJSValue()
    }

    static func fromJSValue (context: JSContext, input: JSValue): List {
        List(input.asObject())
    }
}
```

#### 继承

.d.ts 代码：

```typescript
interface A {
    p: number;
}

interface B extends A {
    p1: number
}

interface C {
    f(): void
}

interface D extends C {
}

interface E extends A {
}

interface F extends C {
    g(): void
}
```

生成的仓颉代码：

```cangjie
public open class A {
    
    protected A(public var p: Float64) {}
    
    
    public open func toJSValue(context: JSContext): JSValue {
        let obj = context.object()
        obj["p"] = p.toJSValue(context)
        obj.toJSValue()
    }
    
    public static func fromJSValue(context: JSContext, input: JSValue): A {
        let obj = input.asObject()
        A(
        Float64.fromJSValue(context, obj["p"])
        )
    }
    
}

/*interface B {
    p1: number;
    }*/

public open class B <: A {
    
    protected B(p: Float64,
    public var p1: Float64) { super(p) }
    
    
    public open func toJSValue(context: JSContext): JSValue {
        let obj = context.object()
        obj["p"] = p.toJSValue(context)
        obj["p1"] = p1.toJSValue(context)
        obj.toJSValue()
    }
    
    public static func fromJSValue(context: JSContext, input: JSValue): B {
        let obj = input.asObject()
        B(
        Float64.fromJSValue(context, obj["p"]),
        Float64.fromJSValue(context, obj["p1"])
        )
    }
    
}

/*interface C {
    f(): void
    }*/

public open class C {
    
    protected C(public var arkts_object: JSObject) {}
    
    
    /**
     * @brief f(): void
     */
    public func f(): Unit {
        jsObjApiCall < Unit >( arkts_object, "f", emptyArg)
    }
    
    public open func toJSValue(context: JSContext): JSValue {
        arkts_object.toJSValue()
    }
    
    static func fromJSValue(context: JSContext, input: JSValue): C {
        C(input.asObject())
    }
}

/*interface D {
    }*/

public open class D <: C {
    
    protected D(arkts_object: JSObject) { super(arkts_object) }
    
    
    
    public open func toJSValue(context: JSContext): JSValue {
        arkts_object.toJSValue()
    }
    
    static func fromJSValue(context: JSContext, input: JSValue): D {
        D(input.asObject())
    }
}

/*interface E {
    }*/

public open class E <: A {
    
    protected E(p: Float64) { super(p) }
    
    
    public open func toJSValue(context: JSContext): JSValue {
        let obj = context.object()
        obj["p"] = p.toJSValue(context)
        obj.toJSValue()
    }
    
    public static func fromJSValue(context: JSContext, input: JSValue): E {
        let obj = input.asObject()
        E(
        Float64.fromJSValue(context, obj["p"])
        )
    }
    
}

/*interface F {
    g(): void
    }*/

public open class F <: C {
    
    protected F(arkts_object: JSObject) { super(arkts_object) }
    
    
    /**
     * @brief g(): void
     */
    public func g(): Unit {
        jsObjApiCall < Unit >( arkts_object, "g", emptyArg)
    }
    
    public open func toJSValue(context: JSContext): JSValue {
        arkts_object.toJSValue()
    }
    
    static func fromJSValue(context: JSContext, input: JSValue): F {
        F(input.asObject())
    }
}
```

#### 嵌套对象

.d.ts 代码：

```typescript
// userProfile.d.ts
interface UserProfile {
  id: number;
  name: string;
  address: {
    city: string;
    zipCode: string;
  };
}
```

生成的仓颉代码：

```cangjie

public open class AutoGenType0 {
    
    protected AutoGenType0(public var : String,
    public var : String) {}
    
    
    public open func toJSValue(context: JSContext): JSValue {
        let obj = context.object()
        obj["city"] = .toJSValue(context)
        obj["zipCode"] = .toJSValue(context)
        obj.toJSValue()
    }
    
    public static func fromJSValue(context: JSContext, input: JSValue): AutoGenType0 {
        let obj = input.asObject()
        AutoGenType0(
        String.fromJSValue(context, obj["city"]),
        String.fromJSValue(context, obj["zipCode"])
        )
    }
    
}


public open class UserProfile {
    
    protected UserProfile(public var id: Float64,
    public var name: String,
    public var address: AutoGenType0) {}
    
    
    public open func toJSValue(context: JSContext): JSValue {
        let obj = context.object()
        obj["id"] = id.toJSValue(context)
        obj["name"] = name.toJSValue(context)
        obj["address"] = address.toJSValue(context)
        obj.toJSValue()
    }
    
    public static func fromJSValue(context: JSContext, input: JSValue): UserProfile {
        let obj = input.asObject()
        UserProfile(
        Float64.fromJSValue(context, obj["id"]),
        String.fromJSValue(context, obj["name"]),
        AutoGenType0.fromJSValue(context, obj["address"])
        )
    }
    
}
```

目前不支持

#### 索引签名

.d.ts 代码：

```typescript
// dictionary.d.ts
interface Dictionary {
  [key: string]: string;
}
// 使用
const dict: Dictionary = {
  name: 'Alice',
  job: 'Developer',
};
console.log(dict['name']); // Alice
```

目前还不支持

#### 动态属性

.d.ts 代码：

```typescript
// config.d.ts
interface Config {
  [key: string]: string | number;
}
```

目前不支持

#### 构造函数

.d.ts 代码：

```typescript
interface ClockConstructor {
  new (hour: number, minute: number): ClockInterface;
}
```

目前不支持

### 类型别名

- 支持枚举类型别名、class 类型别名、函数类型别名、联合类型别名。
- 不支持对象字面量类型别名、命名空间中的类型的类型别名、交叉类型别名、泛型类型别名。

#### 对象字面量类型别名

.d.ts 代码：

```typescript
  type AppConfig = {
    apiUrl: string;
    timeout: number;
  };

  declare const config: AppConfig;
```

目前不支持

#### 枚举类型别名

.d.ts 代码：

```typescript
declare enum Colors {
  Red = 'RED',
  Green = 'GREEN',
  Blue = 'BLUE',
}

type ColorAlias = Colors;
```

生成的仓颉代码：

```cangjie
public type ColorAlias = Colors
```

#### class 类型别名

.d.ts 代码：

```typescript
  declare class Animal {
    name: string;
    constructor(name: string);
    speak(): void;
  }

  type AnimalAlias = Animal;
```

生成的仓颉代码：

```cangjie
public type AnimalAlias = Animal
```

#### 命名空间中的类型的类型别名

.d.ts 代码：

```typescript
declare namespace Shapes {
  type Circle = { radius: number };
  type Rectangle = { width: number; height: number };
}

type CircleAlias = Shapes.Circle;
type RectangleAlias = Shapes.Rectangle;
```

目前不支持

#### 函数类型别名

.d.ts 代码：

```typescript
type MathOperation = (a: number, b: number) => number;
```

生成的仓颉代码：

```cangjie
public type MathOperation = (a: Float64, b: Float64) -> Float64
```

#### 联合类型别名

.d.ts 代码：

```typescript
type GreetingLike = string | number;
```

生成的仓颉代码：

```cangjie
public enum GreetingLike {
    | STRING(String)
    | NUMBER(Float64)

    public func toJSValue(context: JSContext): JSValue {
        match(this) {
            case STRING(x) => context.string(x).toJSValue()
            case NUMBER(x) => context.number(x).toJSValue()
        }
    }
}
```

#### 交叉类型别名

.d.ts 代码：

```typescript
// point.d.ts
interface Point {
  readonly x: number;
  readonly y: number;
}
```

目前不支持

#### 泛型类型别名

.d.ts 代码：

```typescript
// point.d.ts
interface Point {
  readonly x: number;
  readonly y: number;
}
```

目前不支持

### 类

- 支持构造函数、静态成员、私有成员、保护成员、私有属性、泛型成员、抽象类、类实现接口、继承类、重载方法。
- 不支持索引签名、继承、动态属性、嵌套对象、函数类型、构造函数。

#### 构造函数

.d.ts 代码：

```typescript
declare class Greeter {
  constructor(greeting: string);
  greeting: string;
  showGreeting(): void;
}
```

生成的仓颉代码：

```cangjie
public class Greeter {

    protected Greeter(let arkts_object: JSObject) {}
    /**
    * @brief constructor(greeting: string): void
    */
    public init(greeting: String) {
        arkts_object = checkThreadAndCall < JSObject >(getMainContext()) {
            __ctx =>
            let clazz = __ctx.global["Greeter"].asClass(__ctx)
            clazz.new(greeting.toJSValue(__ctx)).asObject()
        }
    }

    public mut prop greeting: String {
        get() {
            checkThreadAndCall < String >(getMainContext()) {
                ctx: JSContext => String.fromJSValue(ctx, arkts_object["greeting"])
            }
        }
        set(v) {
            checkThreadAndCall < Unit >(getMainContext()) {
                ctx: JSContext => arkts_object["greeting"] = v.toJSValue(ctx)
            }
        }

    }

    /**
    * @brief showGreeting(): void
    */
    public func showGreeting(): Unit {
        jsObjApiCall < Unit >( arkts_object, "showGreeting", emptyArg)
    }

    func toJSValue(context: JSContext): JSValue {
        arkts_object.toJSValue()
    }

    static func fromJSValue (context: JSContext, input: JSValue): Greeter {
        Greeter(input.asObject())
    }
}


```

#### 静态成员

.d.ts 代码：

```typescript
// MathUtils.d.ts
declare class MathUtils {
  // 静态属性
  static PI: number;
  // 静态方法
  static square(x: number): number;
}
```

生成的仓颉代码：

```cangjie
public class MathUtils {

    protected MathUtils(let arkts_object: JSObject) {}

    // 静态属性
    public mut prop PI: Float64 {
        get() {
            checkThreadAndCall < Float64 >(getMainContext()) {
                ctx: JSContext => Float64.fromJSValue(ctx, getClassConstructorObj("test", "MathUtils")["PI"])
            }
        }
        set(v) {
            checkThreadAndCall < Unit >(getMainContext()) {
                ctx: JSContext => getClassConstructorObj("test", "MathUtils")["PI"] = v.toJSValue(ctx)
            }
        }

    }

    /**
    * @brief square(x: number): number
    */
    public static func square(x: Float64): Float64 {
        jsObjApiCall < Float64 >(getClassConstructorObj("test", "MathUtils"),  "square", { ctx =>[x.toJSValue(ctx)] })
    }

    func toJSValue(context: JSContext): JSValue {
        arkts_object.toJSValue()
    }

    static func fromJSValue (context: JSContext, input: JSValue): MathUtils {
        MathUtils(input.asObject())
    }
}
```

#### 私有成员

.d.ts 代码：

```typescript
declare class Person {
    // 私有属性
    private age: number;

  }
```

生成的仓颉代码：

```cangjie
public class Person {
    // 不需要生成私有成员属性
    protected Person(let arkts_object: JSObject) {}

    func toJSValue(context: JSContext): JSValue {
        arkts_object.toJSValue()
    }

    static func fromJSValue (context: JSContext, input: JSValue): Person {
        Person(input.asObject())
    }
}
```

#### 保护成员

.d.ts 代码：

```typescript
declare class AnimalProtect {
    // 受保护属性
    protected name: string;

    // 受保护方法
    protected makeSound(): void;
}
```

生成的仓颉代码：

```cangjie
public class AnimalProtect {

    protected AnimalProtect(let arkts_object: JSObject) {}

    // 受保护属性
    public mut prop name: String {
        get() {
            checkThreadAndCall < String >(getMainContext()) {
                ctx: JSContext => String.fromJSValue(ctx, arkts_object["name"])
            }
        }
        set(v) {
            checkThreadAndCall < Unit >(getMainContext()) {
                ctx: JSContext => arkts_object["name"] = v.toJSValue(ctx)
            }
        }

    }

    /**
    * @brief makeSound(): void
    */
    public func makeSound(): Unit {
        jsObjApiCall < Unit >( arkts_object, "makeSound", emptyArg)
    }

    func toJSValue(context: JSContext): JSValue {
        arkts_object.toJSValue()
    }

    static func fromJSValue (context: JSContext, input: JSValue): AnimalProtect {
        AnimalProtect(input.asObject())
    }
}
```

#### 只读属性

.d.ts 代码：

```typescript
declare class Car {
    // 只读属性
    readonly brand: string;
    name: string
  }
```

生成的仓颉代码：

```cangjie
public class Car {

    protected Car(let arkts_object: JSObject) {}

    // 只读属性
    public prop brand: String {
        get() {
            checkThreadAndCall < String >(getMainContext()) {
                ctx: JSContext => String.fromJSValue(ctx, arkts_object["brand"])
            }
        }
    }

    public mut prop name: String {
        get() {
            checkThreadAndCall < String >(getMainContext()) {
                ctx: JSContext => String.fromJSValue(ctx, arkts_object["name"])
            }
        }
        set(v) {
            checkThreadAndCall < Unit >(getMainContext()) {
                ctx: JSContext => arkts_object["name"] = v.toJSValue(ctx)
            }
        }

    }


    func toJSValue(context: JSContext): JSValue {
        arkts_object.toJSValue()
    }

    static func fromJSValue (context: JSContext, input: JSValue): Car {
        Car(input.asObject())
    }
}
```

#### 泛型成员

.d.ts 代码：

```typescript
declare class Box<T> {
    // 属性
    value: T;
    // 方法
    getValue(): T;
  }
```

生成的仓颉代码：

```cangjie
public class Box<T> {

    protected Box(let arkts_object: JSObject) {}

    // 属性
    public mut prop value: T {
        get() {
            checkThreadAndCall < T >(getMainContext()) {
                ctx: JSContext => T.fromJSValue(ctx, arkts_object["value"])
            }
        }
        set(v) {
            checkThreadAndCall < Unit >(getMainContext()) {
                ctx: JSContext => arkts_object["value"] = v.toJSValue(ctx)
            }
        }

    }

    /**
    * @brief getValue(): T
    */
    public func getValue(): T {
        jsObjApiCall < T >( arkts_object, "getValue", emptyArg) {
            ctx, info => T.fromJSValue(ctx, info)
        }
    }

    func toJSValue(context: JSContext): JSValue {
        arkts_object.toJSValue()
    }

    static func fromJSValue <T>(context: JSContext, input: JSValue): Box<T> {
        Box(input.asObject())
    }
}
```

#### 抽象类

.d.ts 代码：

```typescript
declare abstract class Shape {
    // 抽象方法
    abstract getArea(): number;
  }
```

生成的仓颉代码：

```cangjie
public open class Shape {

    protected Shape(let arkts_object: JSObject) {}

    /**
    * @brief getArea(): number
    */
    public func getArea(): Float64 {
        jsObjApiCall < Float64 >( arkts_object, "getArea", emptyArg)
    }

    func toJSValue(context: JSContext): JSValue {
        arkts_object.toJSValue()
    }

    static func fromJSValue (context: JSContext, input: JSValue): Shape {
        Shape(input.asObject())
    }
}
```

#### 类实现接口

.d.ts 代码：

```typescript
interface Drivable {
  start(): void;
  stop(): void;
}

declare class Car implements Drivable {
  start(): void;
  stop(): void;
}
```

生成的仓颉代码：

```cangjie
public class Drivable {

    protected Drivable(let arkts_object: JSObject) {}


    /**
    * @brief start(): void
    */
    public func start(): Unit {
        jsObjApiCall < Unit >( arkts_object, "start", emptyArg)
    }
    /**
    * @brief stop(): void
    */
    public func stop(): Unit {
        jsObjApiCall < Unit >( arkts_object, "stop", emptyArg)
    }

    func toJSValue(context: JSContext): JSValue {
        arkts_object.toJSValue()
    }

    static func fromJSValue (context: JSContext, input: JSValue): Drivable {
        Drivable(input.asObject())
    }
}
public class Car1 <: Drivable {

    protected Car1(arkts_object: JSObject) {}


    /**
    * @brief start(): void
    */
    public func start(): Unit {
        jsObjApiCall < Unit >( arkts_object, "start", emptyArg)
    }
    /**
    * @brief stop(): void
    */
    public func stop(): Unit {
        jsObjApiCall < Unit >( arkts_object, "stop", emptyArg)
    }

    func toJSValue(context: JSContext): JSValue {
        arkts_object.toJSValue()
    }

    static func fromJSValue (context: JSContext, input: JSValue): Car1 {
        Car1(input.asObject())
    }
}
```

#### 继承类

.d.ts 代码：

```typescript
// Animal.d.ts
declare class Animal {
  name: string;
  constructor(name: string);
  move(distance: number): void;
}

// Dog.d.ts
declare class Dog extends Animal {
  bark(): void;
}
```

生成的仓颉代码：

```cangjie
public class Animal1 {

    protected Animal1(let arkts_object: JSObject) {}
    /**
    * @brief constructor(name: string): void
    */
    public init(name: String) {
        arkts_object = checkThreadAndCall < JSObject >(getMainContext()) {
            __ctx =>
            let module = getJSModule(__ctx, "test", None)
            let clazz = module["Animal1"].asClass(__ctx)
            clazz.new(name.toJSValue(__ctx)).asObject()
        }
    }

    public mut prop name: String {
        get() {
            checkThreadAndCall < String >(getMainContext()) {
                ctx: JSContext => String.fromJSValue(ctx, arkts_object["name"])
            }
        }
        set(v) {
            checkThreadAndCall < Unit >(getMainContext()) {
                ctx: JSContext => arkts_object["name"] = v.toJSValue(ctx)
            }
        }

    }

    /**
    * @brief move(distance: number): void
    */
    public func move(distance: Float64): Unit {
        jsObjApiCall < Unit >( arkts_object, "move", { ctx =>[distance.toJSValue(ctx)] })
    }

    func toJSValue(context: JSContext): JSValue {
        arkts_object.toJSValue()
    }

    static func fromJSValue (context: JSContext, input: JSValue): Animal1 {
        Animal1(input.asObject())
    }
}
public class Dog <: Animal1 {

    protected Dog(arkts_object: JSObject) {}


    /**
    * @brief bark(): void
    */
    public func bark(): Unit {
        jsObjApiCall < Unit >( arkts_object, "bark", emptyArg)
    }

    func toJSValue(context: JSContext): JSValue {
        arkts_object.toJSValue()
    }

    static func fromJSValue (context: JSContext, input: JSValue): Dog {
        Dog(input.asObject())
    }
}
```

#### 重载方法

.d.ts 代码：

```typescript
declare class Calculator {
    // 方法重载
    add(x: number, y: number): number;
    add(x: string, y: string): string;

    // 实现
    add(x: any, y: any): any;
  }
```

生成的仓颉代码：

```cangjie
public class Calculator {

    protected Calculator(let arkts_object: JSObject) {}


    /**
    * @brief add(x: number,y: number): number
    */
    public func add(x: Float64, y: Float64): Float64 {
        jsObjApiCall < Float64 >( arkts_object, "add", { ctx =>[x.toJSValue(ctx), y.toJSValue(ctx)] })
    }
    /**
    * @brief add(x: string,y: string): String
    */
    public func add(x: String, y: String): String {
        jsObjApiCall < String >( arkts_object, "add", { ctx =>[x.toJSValue(ctx), y.toJSValue(ctx)] })
    }
    /**
    * @brief add(x: any,y: any): any
    */
    public func add(x: Any, y: Any): any {
        jsObjApiCall < any >( arkts_object, "add", { ctx =>[x.toJSValue(ctx), y.toJSValue(ctx)] }) {
            ctx, info => any.fromJSValue(ctx, info)
        }
    }

    func toJSValue(context: JSContext): JSValue {
        arkts_object.toJSValue()
    }

    static func fromJSValue (context: JSContext, input: JSValue): Calculator {
        Calculator(input.asObject())
    }
}
```

#### 带装饰器的类

.d.ts 代码：

```typescript
// LogClass.d.ts
declare function logClass(target: any): void;

@logClass
declare class MyClass {
  name: string;
  constructor(name: string);
}
```

目前不支持

#### 带命名空间的类

.d.ts 代码：

```typescript
// Shapes.d.ts
declare namespace Shapes {
  class Circle1 {
    radius: number;
    constructor(radius: number);
    getArea(): number;
  }
}
```

目前不支持

### 枚举

- 支持字符串枚举、数字枚举、常量枚举、异构枚举。其中，在仓颉胶水代码里，异构枚举中所有类型的枚举值都会被转换成字符串类型。因此，开发者调用胶水代码时，需要将非字符串类型（例如 number 类型）的异构枚举成员手动转换为 ArkTS 中定义的原类型。
- 不支持计算值枚举。

#### 字符串枚举

.d.ts 代码：

```typescript
// colors.d.ts
declare enum Colors {
  Red = 'RED',
  Green = 'GREEN',
  Blue = 'BLUE',
}
```

生成的仓颉代码：

```cangjie
public enum Colors <: ToString & Equatable < Colors > {
    | Red
    | Green
    | Blue

    func get(): String {
        match(this) {
            case Red => "RED"
            case Green => "GREEN"
            case Blue => "BLUE"
        }
    }

    static func parse(val: String): Colors {
        match(val) {
            case "RED" => Red
            case "GREEN" => Green
            case "BLUE" => Blue
            case _ => throw IllegalArgumentException("unknown value ${val}")
        }
    }

    static func tryParse(val: ?String): ?Colors {
        match(val) {
            case Some(v) => parse(v)
            case None => None
        }
    }

    public func toString(): String {
        get()
    }

    public override operator func ==(that: Colors): Bool {
        match((this, that)) {
            case(Red, Red) => true
            case(Green, Green) => true
            case(Blue, Blue) => true
            case _ => false
        }
    }

    public override operator func !=(that: Colors): Bool {
        !(this == that)
    }
}
```

#### 数字枚举

.d.ts 代码：

```typescript
// status.d.ts
declare enum Status {
  Pending,    // 0
  Approved,   // 1
  Rejected,   // 2
}
```

生成的仓颉代码：

```cangjie
public enum Status <: ToString & Equatable < Status > {
    | Pending
    | Approved
    | Rejected

    func get(): Int32 {
        match(this) {
            case Pending => 0  //todo: please check the value
            case Approved => 1  //todo: please check the value
            case Rejected => 2  //todo: please check the value
        }
    }

    static func parse(val: Int32): Status {
        match(val) {
            case 0 => Pending  //todo: please check the value
            case 1 => Approved  //todo: please check the value
            case 2 => Rejected  //todo: please check the value
            case _ => throw IllegalArgumentException("unknown value ${val}")
        }
    }

    static func tryParse(val: ?Int32): ?Status {
        match(val) {
            case Some(v) => parse(v)
            case None => None
        }
    }

    public func toString(): String {
        match(this) {
            case Pending => "Pending"
            case Approved => "Approved"
            case Rejected => "Rejected"
        }
    }

    public override operator func ==(that: Status): Bool {
        match((this, that)) {
            case(Pending, Pending) => true
            case(Approved, Approved) => true
            case(Rejected, Rejected) => true
            case _ => false
        }
    }

    public override operator func !=(that: Status): Bool {
        !(this == that)
    }
}
```

#### 常量枚举

.d.ts 代码：

```typescript
// constants.d.ts
declare const enum Status {
  Pending = 3,
  Approved = 4,
  Rejected = 5
}
```

生成的仓颉代码：

```cangjie
public enum Status <: ToString & Equatable < Status > {
    | Pending
    | Approved
    | Rejected

    func get(): Int32 {
        match(this) {
            case Pending => 3
            case Approved => 4
            case Rejected => 5
        }
    }

    static func parse(val: Int32): Status {
        match(val) {
            case 3 => Pending
            case 4 => Approved
            case 5 => Rejected
            case _ => throw IllegalArgumentException("unknown value ${val}")
        }
    }

    static func tryParse(val: ?Int32): ?Status {
        match(val) {
            case Some(v) => parse(v)
            case None => None
        }
    }

    public func toString(): String {
        match(this) {
            case Pending => "Pending"
            case Approved => "Approved"
            case Rejected => "Rejected"
        }
    }

    public override operator func ==(that: Status): Bool {
        match((this, that)) {
            case(Pending, Pending) => true
            case(Approved, Approved) => true
            case(Rejected, Rejected) => true
            case _ => false
        }
    }

    public override operator func !=(that: Status): Bool {
        !(this == that)
    }
}
```

#### 异构枚举

.d.ts 代码：

```typescript
// response.d.ts
declare enum Response {
  No = 0,
  Yes = 'YES',
}
```

生成的仓颉代码：

```cangjie
public enum Response <: ToString & Equatable < Response > {
    | No
    | Yes

    func get(): String {
        match(this) {
            case No => "0"
            case Yes => "YES"
        }
    }

    static func parse(val: String): Response {
        match(val) {
            case "0" => No
            case "YES" => Yes
            case _ => throw IllegalArgumentException("unknown value ${val}")
        }
    }

    static func tryParse(val: ?String): ?Response {
        match(val) {
            case Some(v) => parse(v)
            case None => None
        }
    }

    public func toString(): String {
        get()
    }

    public override operator func ==(that: Response): Bool {
        match((this, that)) {
            case(No, No) => true
            case(Yes, Yes) => true
            case _ => false
        }
    }

    public override operator func !=(that: Response): Bool {
        !(this == that)
    }
}
```

## 类型映射关系

ArkTS 的 .d.ts 接口转换到互操作的仓颉代码，支持的类型转换有：基础类型、Array 类型、函数类型、Optional 类型、Object 类型、tuple 类型、Union 类型、Promise 类型。

对于不支持的类型，会默认改成 JSValue 类型，并且会添加一个 FIXME 的注释（注释中会填写原始的 .d.ts 声明中的类型），命令行也会打印类型不支持的告警信息。

- 注释的格式

  .d.ts 代码：

  ```typescript
  type TA80 = undefined;
  ```

  对应的仓颉代码：

  ```typescript
  // 对应的仓颉代码的类型是JSValue，并且会带FIXME的注释信息，其中填写的.d.ts中声明的类型
  public type TA80 = JSValue/* FIXME: `undefined` */
  ```

- 告警信息的格式：

  ```typescript
  WARNING: type is not supported - undefined
  ```

### 基础类型

支持的数据类型有：

| ArkTS 类型 | 仓颉类型 |
| --------- | -------- |
| string    | String   |
| number    | Float64  |
| boolean   | bool     |
| bigint    | BigInt   |
| object    | JSValue  |
| symbol    | JSValue  |
| void      | Unit     |
| undefined | JSValue  |
| any       | Any      |
| unknown   | JSValue  |
| never     | JSValue  |

示例：

.d.ts 代码：

```typescript
interface BasicTypes {
    numberKeyword: number;
    stringKeyword: string;
    booleanKeyword: boolean;
    bigintKeyword: bigint;
    objectKeyword: object;
    symbolKeyword: symbol;
    voidKeyword: void;
    undefinedKeyword: undefined;
    anyKeyword: any;
    unknownKeyword: unknown;
    neverKeyword: never;
}
```

生成的仓颉代码：

```cangjie
public class BasicTypes {

    protected BasicTypes(public var numberKeyword: Float64,
    public var stringKeyword: String,
    public var booleanKeyword: Bool,
    public var bigintKeyword: BigInt,
    public var objectKeyword: JSValue/* FIXME: `object` */,
    public var symbolKeyword: JSValue/* FIXME: `symbol` */,
    public var voidKeyword: Unit,
    public var undefinedKeyword: JSValue/* FIXME: `undefined` */,
    public var anyKeyword: Any,
    public var unknownKeyword: JSValue/* FIXME: `unknown` */,
    public var neverKeyword: JSValue/* FIXME: `never` */) {}


    public func toJSValue(context: JSContext): JSValue {
        let obj = context.object()
        obj["numberKeyword"] = numberKeyword.toJSValue(context)
        obj["stringKeyword"] = stringKeyword.toJSValue(context)
        obj["booleanKeyword"] = booleanKeyword.toJSValue(context)
        obj["bigintKeyword"] = context.bigint(bigintKeyword).toJSValue(context)
        obj["objectKeyword"] = objectKeyword
        obj["symbolKeyword"] = symbolKeyword
        obj["voidKeyword"] = voidKeyword.toJSValue(context)
        obj["undefinedKeyword"] = undefinedKeyword
        obj["anyKeyword"] = anyKeyword.toJSValue(context)
        obj["unknownKeyword"] = unknownKeyword
        obj["neverKeyword"] = neverKeyword
        obj.toJSValue()
    }

    public static func fromJSValue (context: JSContext, input: JSValue): BasicTypes {
        let obj = input.asObject()
        BasicTypes(
        Float64.fromJSValue(context, obj["numberKeyword"]),
        String.fromJSValue(context, obj["stringKeyword"]),
        Bool.fromJSValue(context, obj["booleanKeyword"]),
        obj["bigintKeyword"].asBigInt(context).toBigInt(),
        JSValue/* FIXME: `object` */.fromJSValue(context, obj["objectKeyword"]),
        JSValue/* FIXME: `symbol` */.fromJSValue(context, obj["symbolKeyword"]),
        Unit.fromJSValue(context, obj["voidKeyword"]),
        JSValue/* FIXME: `undefined` */.fromJSValue(context, obj["undefinedKeyword"]),
        Any.fromJSValue(context, obj["anyKeyword"]),
        JSValue/* FIXME: `unknown` */.fromJSValue(context, obj["unknownKeyword"]),
        JSValue/* FIXME: `never` */.fromJSValue(context, obj["neverKeyword"])
        )
    }

}
```

### Array

Array 目前支持 4 种类型转换：

| ArkTS 类型                     | 仓颉类型       |
| ----------------------------- | -------------- |
| Uint8Array                    | Array\<UInt8>   |
| ArrayBuffer                   | Array\<UInt8>   |
| Float32Array                  | Array\<Float32> |
| 基本类型的 array，比如 number[] | Array\<Float64> |

示例：

.d.ts 代码：

```typescript
interface arrayInterface {
  arrayType1: number[];
  arrayType2: Uint8Array;
  arrayType3: ArrayBuffer;
  arrayType4: Float32Array;
}
```

生成的仓颉代码：

```cangjie
public class arrayInterface {

    protected arrayInterface(public var arrayType1: Array<Float64>,
    public var arrayType2: Array<UInt8>,
    public var arrayType3: Array<UInt8>,
    public var arrayType4: Array<Float32>) {}


    public func toJSValue(context: JSContext): JSValue {
        let obj = context.object()
        obj["arrayType1"] = toJSArray(context, arrayType1)
        obj["arrayType2"] = toJSArray(context, arrayType2, { ctx: JSContext, val: UInt8 => val.toJSValue(ctx) })
        obj["arrayType3"] = toJSArray(context, arrayType3, { ctx: JSContext, val: UInt8 => val.toJSValue(ctx) })
        obj["arrayType4"] = toJSArray(context, arrayType4, { ctx: JSContext, val: Float32 => val.toJSValue(ctx) })
        obj.toJSValue()
    }

    public static func fromJSValue (context: JSContext, input: JSValue): arrayInterface {
        let obj = input.asObject()
        arrayInterface(
        fromJSArray < Float64 >(context, obj["arrayType1"]),
        fromJSArray(context, obj["arrayType2"], { ctx: JSContext, val: JSValue => UInt8.fromJSValue(ctx, val) }),
        fromJSArray(context, obj["arrayType3"], { ctx: JSContext, val: JSValue => UInt8.fromJSValue(ctx, val) }),
        fromJSArray(context, obj["arrayType4"], { ctx: JSContext, val: JSValue => Float32.fromJSValue(ctx, val) })
        )
    }

}
```

### 函数类型

- 支持接口属性、函数参数。
- `Function`类型不支持转换。

#### 接口属性

示例：

.d.ts 代码：

```typescript
interface TestListener {
    "onStart"?: () => void;
    "onDestroy"?: () => void;
    onError?: (code: ErrorCode, msg: string) => void;
    onTouch?: () => void;
    onEvent?: (e: EventType) => void;
}
```

生成的仓颉代码：

```cangjie
public class TestListener {

    protected TestListener(public var onStart!: Option<() -> Unit> = None,
    public var onDestroy!: Option<() -> Unit> = None,
    public var onError!: Option<(code: ErrorCode, msg: String) -> Unit> = None,
    public var onTouch!: Option<() -> Unit> = None,
    public var onEvent!: Option<(e: EventType) -> Unit> = None) {}


    public func toJSValue(context: JSContext): JSValue {
        let obj = context.object()
        if(let Some(v) <- onStart) {
            obj["onStart"] = context.function({ ctx, _ =>
                v()
                ctx.undefined().toJSValue()
            }).toJSValue()
        }
        if(let Some(v) <- onDestroy) {
            obj["onDestroy"] = context.function({ ctx, _ =>
                v()
                ctx.undefined().toJSValue()
            }).toJSValue()
        }
        if(let Some(v) <- onError) {
            obj["onError"] = context.function({ ctx, info =>
                let p0 = ErrorCode.fromJSValue(ctx, info[0])
                let p1 = String.fromJSValue(ctx, info[1])
                v(p0, p1)
                ctx.undefined().toJSValue()
            }).toJSValue()
        }
        if(let Some(v) <- onTouch) {
            obj["onTouch"] = context.function({ ctx, _ =>
                v()
                ctx.undefined().toJSValue()
            }).toJSValue()
        }
        if(let Some(v) <- onEvent) {
            obj["onEvent"] = context.function({ ctx, info =>
                let p0 = EventType.parse(Int32.fromJSValue(ctx, info[0]))
                v(p0)
                ctx.undefined().toJSValue()
            }).toJSValue()
        }
        obj.toJSValue()
    }

    public static func fromJSValue (context: JSContext, input: JSValue): TestListener {
        let obj = input.asObject()
        TestListener(
        onStart: if(obj["onStart"].isUndefined()) {
            None
        } else {
            { =>
                checkThreadAndCall < Unit >(context, { _ =>
                    obj["onStart"].asFunction().call()
                })
            }
        },
        onDestroy: if(obj["onDestroy"].isUndefined()) {
            None
        } else {
            { =>
                checkThreadAndCall < Unit >(context, { _ =>
                    obj["onDestroy"].asFunction().call()
                })
            }
        },
        onError: if(obj["onError"].isUndefined()) {
            None
        } else {
            { code: ErrorCode, msg: String =>
                checkThreadAndCall < Unit >(context, { ctx =>
                    let arg0 = code.toJSValue(ctx)
                    let arg1 = msg.toJSValue(ctx)
                    obj["onError"].asFunction().call([arg0, arg1])
                })
            }
        },
        onTouch: if(obj["onTouch"].isUndefined()) {
            None
        } else {
            { =>
                checkThreadAndCall < Unit >(context, { _ =>
                    obj["onTouch"].asFunction().call()
                })
            }
        },
        onEvent: if(obj["onEvent"].isUndefined()) {
            None
        } else {
            { e: EventType =>
                checkThreadAndCall < Unit >(context, { ctx =>
                    let arg0 = e.get().toJSValue(ctx)
                    obj["onEvent"].asFunction().call([arg0])
                })
            }
        }
        )
    }

}
```

#### 函数参数

示例：

.d.ts 代码：

```typescript
interface MyListener {
    on(key: string, param: boolean, cb: (r: Record<string, string>) => void);
}
```

生成的仓颉代码：

```cangjie
public class MyListener {
    let callbackManager = CallbackManager < String, JSValue >()
    protected MyListener(let arkts_object: JSObject) {}

    /**
    * @brief on(key: string,param: boolean,cb: (r: Record<string, string>) => void): void
    */
    public func on(key: String, param: Bool, cb: Callback1Argument<Record>): Unit {
        let key = key.toString()
        if(callbackManager.findCallbackObject(key, cb).isSome()) {
            return
        }
        let jsCallback = checkThreadAndCall < JSValue >(getMainContext()) {
            __ctx => __ctx.function {
                __ctx: JSContext, info: JSCallInfo =>
                let arg0 = Record<stringstring>.fromJSValue(__ctx, info[0])
                cb.invoke(arg0)
                __ctx.undefined().toJSValue()
            }.toJSValue()
        }
        callbackManager.put(key,(cb, jsCallback))
        jsObjApiCall < Unit >( arkts_object, "on", { __ctx =>[key.toJSValue(__ctx), param.toJSValue(__ctx), jsCallback] })
    }

    func toJSValue(context: JSContext): JSValue {
        arkts_object.toJSValue()
    }

    static func fromJSValue (context: JSContext, input: JSValue): MyListener {
        MyListener(input.asObject())
    }
}
```

### Optional 类型

示例：

.d.ts 代码：

```typescript
interface Optionals {
    optionalField1?: number;
    optionalParam10: (a: number, b?: string) => void;
}
```

生成的仓颉代码：

```cangjie
public class Optionals {

    protected Optionals(public var optionalParam10: (a: Float64, b: ?String) -> Unit,
    public var optionalField1!: Option<Float64> = None) {}


    public func toJSValue(context: JSContext): JSValue {
        let obj = context.object()
        obj["optionalParam10"] = context.function({ ctx, info =>
            let p0 = Float64.fromJSValue(ctx, info[0])
            let p1 = String.fromJSValue(ctx, info[1])
            optionalParam10(p0, p1)
            ctx.undefined().toJSValue()
        }).toJSValue()
        if(let Some(v) <- optionalField1) {
            obj["optionalField1"] = v.toJSValue(context)
        }
        obj.toJSValue()
    }

    public static func fromJSValue (context: JSContext, input: JSValue): Optionals {
        let obj = input.asObject()
        Optionals(
        { a: Float64, b:?String =>
            checkThreadAndCall < Unit >(context, { ctx =>
                let arg0 = a.toJSValue(ctx)
                let arg1 = b?.toJSValue(ctx)
                obj["optionalParam10"].asFunction().call([arg0, arg1])
            })
        },
        optionalField1: if(obj["optionalField1"].isUndefined()) {
            None
        } else {
            Float64.fromJSValue(context, obj["optionalField1"])
        }
        )
    }

}
```

### Object 类型

示例：

.d.ts 代码：

```typescript
interface ObjectTypes<U, T> {
    typeLiteral10: { x: number; y: U; };
    typeLiteral20: { [p: number]: string; [p: symbol]: T };
    typeLiteral30: { (): void; (number): string };
}
```

当前类型不支持，会默认转换成 JSValue。

生成的仓颉代码：

```cangjie
public class ObjectTypes<U, T> {

    protected ObjectTypes(public var typeLiteral10: JSValue/* FIXME: `{ x: number; y: U }` */,
    public var typeLiteral20: JSValue/* FIXME: `{ [number]: string; [symbol]: T }` */,
    public var typeLiteral30: JSValue/* FIXME: `{ () => void; (number: any) => string }` */) {}


    public func toJSValue(context: JSContext): JSValue {
        let obj = context.object()
        obj["typeLiteral10"] = typeLiteral10
        obj["typeLiteral20"] = typeLiteral20
        obj["typeLiteral30"] = typeLiteral30
        obj.toJSValue()
    }

    public static func fromJSValue <U, T>(context: JSContext, input: JSValue): ObjectTypes<U, T> {
        let obj = input.asObject()
        ObjectTypes(
        JSValue/* FIXME: `{ x: number; y: U }` */.fromJSValue(context, obj["typeLiteral10"]),
        JSValue/* FIXME: `{ [number]: string; [symbol]: T }` */.fromJSValue(context, obj["typeLiteral20"]),
        JSValue/* FIXME: `{ () => void; (number: any) => string }` */.fromJSValue(context, obj["typeLiteral30"])
        )
    }

}
```

### tuple 类型

示例：

.d.ts 代码：

```typescript
tupleType: [number, number, string];
```

生成的仓颉代码：

```cangjie
public var tupleType: Tuple<Float64, Float64, String>
```

### Union 类型

- 目前只支持 union 类型作为类型别名和函数参数。

示例：

.d.ts 代码：

```typescript
type ARK1 = null | number | string | boolean | Uint8Array | Float32Array | bigint;
```

生成的仓颉代码：

```cangjie
public enum ARK1 {
    | NULL
    | NUMBER(Float64)
    | STRING(String)
    | BOOLEAN(Bool)
    | BYTEARRAY(Array<UInt8>)
    | FLOAT32ARRAY(Array<Float32>)
    | BIGINT(BigInt)

    public func toJSValue(context: JSContext): JSValue {
        match(this) {
            case NULL => context.null().toJSValue()
            case NUMBER(x) => context.number(x).toJSValue()
            case STRING(x) => context.string(x).toJSValue()
            case BOOLEAN(x) => context.boolean(x).toJSValue()
            case BYTEARRAY(x) => context.global["Uint8Array"].asClass().new(x.toJSValue(context))
            case FLOAT32ARRAY(x) => let buffer = context.arrayBuffer(acquireArrayRawData(x), x.size, { pt => releaseArrayRawData(pt)})
context.global["Float32Array"].asClass().new(buffer.toJSValue())
            case BIGINT(x) => context.bigint(x).toJSValue()
        }
    }
}

public enum ARK2 {
    | ARK1(x)
    | VOID(Unit)

    public func toJSValue(context: JSContext): JSValue {
        match(this) {
            case ARK1(x) => x.toJSValue(context)
        }
    }
}
```

### Promise 类型

.d.ts 代码：

```typescript
typeReference21: Promise<T>;
```

生成的仓颉代码：

```cangjie
public var typeReference21: Promise<T>,
```

### 交叉类型

.d.ts 代码：

```typescript
interface IntersectionTypes<U, T> {
  intersectionType: object & Record<U, T>;
}
```

当前类型不支持，会默认转换成 JSValue。

生成的仓颉代码：

```cangjie
public class IntersectionTypes<U, T> {

    protected IntersectionTypes(public var intersectionType: JSValue/* FIXME: `object & HashMap<U, T>` */) {}


    public func toJSValue(context: JSContext): JSValue {
        let obj = context.object()
        obj["intersectionType"] = intersectionType
        obj.toJSValue()
    }

    public static func fromJSValue <U, T>(context: JSContext, input: JSValue): IntersectionTypes<U, T> {
        let obj = input.asObject()
        IntersectionTypes(
        JSValue/* FIXME: `object & HashMap<U, T>` */.fromJSValue(context, obj["intersectionType"])
        )
    }

}
```

### 导入

- 目前导入会翻译，但是还是需要用户收到确认修改。

.d.ts 代码：

```typescript
import { a } from '@umeng/common';
import buffer from '@ohos.buffer';
import { e } from "../g/h";

import { MyStringEnum, MyNumericEnum } from './exportAlias'; // Type Imports
declare const value1: MyStringEnum;
declare const value2: MyNumericEnum;

import * as Inheritances from './inheritances'; // Module Import
declare function createSub(): Inheritances.SubClass;

import { ExportedInterface } from './exportAlias'; // Module Augmentation
declare module './exportAlias' {
    interface ExportedInterface {
        myOption?: string;
    }
}
```

生成的仓颉代码：

```cangjie
/***********IMPORT***********/
/*FIXME: Import details need to be verified and rewritten by user.*/
/*import { a } from '@umeng/common';*/

/*FIXME: Import details need to be verified and rewritten by user.*/
/*import buffer from '@ohos.buffer';*/

/*FIXME: Import details need to be verified and rewritten by user.*/
/*import { e } from "../g/h";*/

/*FIXME: Import details need to be verified and rewritten by user.*/
/*import { MyStringEnum, MyNumericEnum } from './exportAlias';*/

/*FIXME: Import details need to be verified and rewritten by user.*/
/*import * as Inheritances from './inheritances';*/

/*FIXME: Import details need to be verified and rewritten by user.*/
/*import { ExportedInterface } from './exportAlias';*/


/*

public const value1 = 0/* FIXME: Initialization is required */
*/
/*

public const value2 = 0/* FIXME: Initialization is required */
*/

/***********METHOD***********/
/**
  * @brief createSub(): Inheritances.SubClass
  */
public func createSub(): JSValue/* FIXME: `Inheritances.SubClass` */ {
    hmsGlobalApiCall < JSValue/* FIXME: `Inheritances.SubClass` */ >( "my_module_imports", "createSub", emptyArg) {
        ctx, info => info
    }
}


/***********OBJECT***********/

/*interface ExportedInterface {
    myOption?: String;
    }*/

public open class ExportedInterface {
    
    protected ExportedInterface(public var myOption!: Option<String> = None) {}
    
    
    public open func toJSValue(context: JSContext): JSValue {
        let obj = context.object()
        if(let Some(v) <- myOption) {
            obj["myOption"] = v.toJSValue(context)
        }
        obj.toJSValue()
    }
    
    public static func fromJSValue(context: JSContext, input: JSValue): ExportedInterface {
        let obj = input.asObject()
        ExportedInterface(
        myOption: Option < String >.fromJSValue(context, obj["myOption"])
        )
    }
    
}
```