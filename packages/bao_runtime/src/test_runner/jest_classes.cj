// jest_classes.cj - Jest/Expect 绑定类定义元数据
// 严格翻译自 bun/src/runtime/test_runner/jest.classes.ts

package bao_runtime.test_runner

import std.collection.*

/// 绑定类属性描述。
/// 对应 jest.classes.ts 中 define(...).klass/proto 的函数、getter 与值属性条目。
public class BindClassPropertyDef {
    public var name: String
    public var fn: ?String = None
    public var getter: ?String = None
    public var length: ?UInt32 = None
    public var this_: Bool = false
    public var cache: Bool = false

    public init(name: String, fn: ?String, getter: ?String, length: ?UInt32, this_: Bool, cache: Bool) {
        this.name = name
        this.fn = fn
        this.getter = getter
        this.size = length
        this.this_ = this_
        this.cache = cache
    }
}

/// 绑定类定义。
/// 该文件保留 Bun codegen 输入的 1:1 元数据，实际类实现分散在 expect.cj、scope_functions.cj、done_callback.cj。
public class BindClassDef {
    public var name: String
    public var construct: Bool
    public var noConstructor: Bool
    public var call: Bool
    public var finalize: Bool
    public var forBind: Bool
    public var jsType: String
    public var values: ArrayList<String>
    public var configurable: Bool
    public var klass: ArrayList<BindClassPropertyDef>
    public var proto: ArrayList<BindClassPropertyDef>

    public init(
        name: String,
        construct: Bool,
        noConstructor: Bool,
        call: Bool,
        finalize: Bool,
        forBind: Bool,
        jsType: String,
        values: ArrayList<String>,
        configurable: Bool,
        klass: ArrayList<BindClassPropertyDef>,
        proto: ArrayList<BindClassPropertyDef>
    ) {
        this.name = name
        this.construct = construct
        this.noConstructor = noConstructor
        this.call = call
        this.finalize = finalize
        this.forBind = forBind
        this.jsType = jsType
        this.values = values
        this.configurable = configurable
        this.klass = klass
        this.proto = proto
    }
}

private func `prop`(name!: String, fn!: String, length!: ?UInt32): BindClassPropertyDef {
    return BindClassPropertyDef(name, fn, None, length, false, false)
}

private func propNoLen(name!: String, fn!: String): BindClassPropertyDef {
    return BindClassPropertyDef(name, fn, None, None, false, false)
}

private func getter(name!: String, getterName!: String, this_!: Bool, cache!: Bool): BindClassPropertyDef {
    return BindClassPropertyDef(name, None, getterName, None, this_, cache)
}

private func cls(
        name: String,
    noConstructor: Bool,
    call: Bool,
    finalize: Bool,
    forBind: Bool,
    values: ArrayList<String>,
    klass: ArrayList<BindClassPropertyDef>,
    proto: ArrayList<BindClassPropertyDef>
): BindClassDef {
    return cls(
        name: name,
        construct: false,
        noConstructor: noConstructor,
        call: call,
        finalize: finalize,
        forBind: forBind,
        jsType: "0b11101110",
        values: values,
        configurable: false,
        klass: klass,
        proto: proto
    )
}

/// jest.classes.ts default export 的 Cangjie 等价元数据。
public let jestClassDefinitions: ArrayList<BindClassDef> = ArrayList<BindClassDef>([
    cls(name: "ExpectAnything", noConstructor: true, call: true, finalize: true),
    cls(name: "ExpectAny", noConstructor: true, call: true, finalize: true, values: ArrayList<String>(["constructorValue"])),
    cls(name: "ExpectCloseTo", noConstructor: true, call: true, finalize: true, values: ArrayList<String>(["numberValue", "digitsValue"])),
    cls(name: "ExpectObjectContaining", noConstructor: true, call: true, finalize: true, values: ArrayList<String>(["objectValue"])),
    cls(name: "ExpectStringContaining", noConstructor: true, call: true, finalize: true, values: ArrayList<String>(["stringValue"])),
    cls(name: "ExpectStringMatching", noConstructor: true, call: true, finalize: true, values: ArrayList<String>(["testValue"])),
    cls(name: "ExpectArrayContaining", noConstructor: true, call: true, finalize: true, values: ArrayList<String>(["arrayValue"])),
    cls(
        name: "ExpectCustomAsymmetricMatcher",
        noConstructor: true,
        finalize: true,
        values: ArrayList<String>(["matcherFn", "capturedArgs"]),
        proto: ArrayList<BindClassPropertyDef>([`prop`(name: "asymmetricMatch", fn: "asymmetricMatch", length: 1)])
    ),
    cls(
        name: "ExpectMatcherContext",
        noConstructor: true,
        finalize: true,
        proto: ArrayList<BindClassPropertyDef>([
            getter(name: "utils", getterName: "getUtils", this_: false, cache: false),
            getter(name: "isNot", getterName: "getIsNot", this_: false, cache: false),
            getter(name: "promise", getterName: "getPromise", this_: false, cache: false),
            getter(name: "expand", getterName: "getExpand", this_: false, cache: false),
            `prop`(name: "equals", fn: "equals", length: 3)
        ])
    ),
    cls(
        name: "ExpectMatcherUtils",
        noConstructor: true,
        finalize: true,
        proto: ArrayList<BindClassPropertyDef>([
            `prop`(name: "stringify", fn: "stringify", length: 1),
            `prop`(name: "printExpected", fn: "printExpected", length: 1),
            `prop`(name: "printReceived", fn: "printReceived", length: 1),
            `prop`(name: "EXPECTED_COLOR", fn: "printExpected", length: 1),
            `prop`(name: "RECEIVED_COLOR", fn: "printReceived", length: 1),
            `prop`(name: "matcherHint", fn: "matcherHint", length: 1)
        ])
    ),
    cls(
        name: "ExpectStatic",
        noConstructor: true,
        finalize: true,
        proto: ArrayList<BindClassPropertyDef>([
            `prop`(name: "anything", fn: "anything", length: 1),
            `prop`(name: "any", fn: "any", length: 1),
            `prop`(name: "arrayContaining", fn: "arrayContaining", length: 1),
            `prop`(name: "closeTo", fn: "closeTo", length: 1),
            `prop`(name: "objectContaining", fn: "objectContaining", length: 1),
            `prop`(name: "stringContaining", fn: "stringContaining", length: 1),
            `prop`(name: "stringMatching", fn: "stringMatching", length: 1),
            getter(name: "not", getterName: "getNot", this_: true, cache: false),
            getter(name: "resolvesTo", getterName: "getResolvesTo", this_: true, cache: false),
            getter(name: "rejectsTo", getterName: "getRejectsTo", this_: true, cache: false)
        ])
    ),
    cls(
        name: "Expect",
        construct: true,
        call: true,
        finalize: true,
        values: ArrayList<String>(["capturedValue", "resultValue"]),
        klass: ArrayList<BindClassPropertyDef>([
            `prop`(name: "extend", fn: "extend", length: 1),
            `prop`(name: "anything", fn: "anything", length: 1),
            `prop`(name: "any", fn: "any", length: 1),
            `prop`(name: "arrayContaining", fn: "arrayContaining", length: 1),
            `prop`(name: "assertions", fn: "assertions", length: 1),
            `prop`(name: "hasAssertions", fn: "hasAssertions", length: 1),
            `prop`(name: "closeTo", fn: "closeTo", length: 1),
            `prop`(name: "objectContaining", fn: "objectContaining", length: 1),
            `prop`(name: "stringContaining", fn: "stringContaining", length: 1),
            `prop`(name: "stringMatching", fn: "stringMatching", length: 1),
            `prop`(name: "addSnapshotSerializer", fn: "addSnapshotSerializer", length: 1),
            getter(name: "not", getterName: "getStaticNot", this_: false, cache: false),
            getter(name: "resolvesTo", getterName: "getStaticResolvesTo", this_: false, cache: false),
            getter(name: "rejectsTo", getterName: "getStaticRejectsTo", this_: false, cache: false),
            `prop`(name: "unreachable", fn: "doUnreachable", length: 1)
        ]),
        proto: expectProtoDefinitions
    ),
    cls(
        name: "ExpectTypeOf",
        construct: true,
        call: true,
        finalize: true,
        proto: expectTypeOfProtoDefinitions
    ),
    cls(name: "DoneCallback", noConstructor: true, finalize: true),
    cls(
        name: "ScopeFunctions",
        noConstructor: true,
        forBind: true,
        finalize: true,
        values: ArrayList<String>(["each"]),
        proto: ArrayList<BindClassPropertyDef>([
            getter(name: "skip", getterName: "getSkip", this_: false, cache: true),
            getter(name: "todo", getterName: "getTodo", this_: false, cache: true),
            getter(name: "failing", getterName: "getFailing", this_: false, cache: true),
            getter(name: "concurrent", getterName: "getConcurrent", this_: false, cache: true),
            getter(name: "serial", getterName: "getSerial", this_: false, cache: true),
            getter(name: "only", getterName: "getOnly", this_: false, cache: true),
            `prop`(name: "if", fn: "fnIf", length: 1),
            `prop`(name: "skipIf", fn: "fnSkipIf", length: 1),
            `prop`(name: "todoIf", fn: "fnTodoIf", length: 1),
            `prop`(name: "failingIf", fn: "fnFailingIf", length: 1),
            `prop`(name: "concurrentIf", fn: "fnConcurrentIf", length: 1),
            `prop`(name: "serialIf", fn: "fnSerialIf", length: 1),
            `prop`(name: "each", fn: "fnEach", length: 1)
        ])
    )
])

public let expectProtoDefinitions: ArrayList<BindClassPropertyDef> = ArrayList<BindClassPropertyDef>([
    `prop`(name: "pass", fn: "_pass", length: 1),
    `prop`(name: "fail", fn: "fail", length: 1),
    `prop`(name: "toBe", fn: "toBe", length: 1),
    `prop`(name: "toBeCalled", fn: "toHaveBeenCalled", length: 0),
    `prop`(name: "toHaveBeenCalled", fn: "toHaveBeenCalled", length: 0),
    `prop`(name: "toHaveBeenCalledOnce", fn: "toHaveBeenCalledOnce", length: 0),
    `prop`(name: "toHaveBeenCalledTimes", fn: "toHaveBeenCalledTimes", length: 1),
    `prop`(name: "toBeCalledTimes", fn: "toHaveBeenCalledTimes", length: 1),
    `prop`(name: "toHaveBeenCalledWith", fn: "toHaveBeenCalledWith", length: None),
    `prop`(name: "toBeCalledWith", fn: "toHaveBeenCalledWith", length: None),
    `prop`(name: "toHaveBeenLastCalledWith", fn: "toHaveBeenLastCalledWith", length: None),
    `prop`(name: "lastCalledWith", fn: "toHaveBeenLastCalledWith", length: None),
    `prop`(name: "toHaveBeenNthCalledWith", fn: "toHaveBeenNthCalledWith", length: None),
    `prop`(name: "nthCalledWith", fn: "toHaveBeenNthCalledWith", length: None),
    `prop`(name: "toHaveReturnedTimes", fn: "toHaveReturnedTimes", length: 1),
    `prop`(name: "toReturn", fn: "toHaveReturned", length: 1),
    `prop`(name: "toHaveReturned", fn: "toHaveReturned", length: 1),
    `prop`(name: "toHaveReturnedWith", fn: "toHaveReturnedWith", length: 1),
    `prop`(name: "toHaveLastReturnedWith", fn: "toHaveLastReturnedWith", length: 1),
    `prop`(name: "lastReturnedWith", fn: "toHaveLastReturnedWith", length: 1),
    `prop`(name: "toHaveNthReturnedWith", fn: "toHaveNthReturnedWith", length: 1),
    `prop`(name: "nthReturnedWith", fn: "toHaveNthReturnedWith", length: 1),
    `prop`(name: "toHaveLength", fn: "toHaveLength", length: 1),
    `prop`(name: "toHaveProperty", fn: "toHaveProperty", length: 2),
    `prop`(name: "toBeCloseTo", fn: "toBeCloseTo", length: 1),
    `prop`(name: "toBeGreaterThan", fn: "toBeGreaterThan", length: 1),
    `prop`(name: "toBeGreaterThanOrEqual", fn: "toBeGreaterThanOrEqual", length: 1),
    `prop`(name: "toBeLessThan", fn: "toBeLessThan", length: 1),
    `prop`(name: "toBeLessThanOrEqual", fn: "toBeLessThanOrEqual", length: 1),
    `prop`(name: "toBeInstanceOf", fn: "toBeInstanceOf", length: 1),
    `prop`(name: "toBeTruthy", fn: "toBeTruthy", length: 0),
    `prop`(name: "toBeUndefined", fn: "toBeUndefined", length: 0),
    `prop`(name: "toBeNaN", fn: "toBeNaN", length: 0),
    `prop`(name: "toBeNull", fn: "toBeNull", length: 0),
    `prop`(name: "toBeFalsy", fn: "toBeFalsy", length: 0),
    `prop`(name: "toBeDefined", fn: "toBeDefined", length: 0),
    `prop`(name: "toContain", fn: "toContain", length: 1),
    `prop`(name: "toContainKey", fn: "toContainKey", length: 1),
    `prop`(name: "toContainAllKeys", fn: "toContainAllKeys", length: 1),
    `prop`(name: "toContainAnyKeys", fn: "toContainAnyKeys", length: 1),
    `prop`(name: "toContainValue", fn: "toContainValue", length: 1),
    `prop`(name: "toContainValues", fn: "toContainValues", length: 1),
    `prop`(name: "toContainAllValues", fn: "toContainAllValues", length: 1),
    `prop`(name: "toContainAnyValues", fn: "toContainAnyValues", length: 1),
    `prop`(name: "toContainKeys", fn: "toContainKeys", length: 1),
    `prop`(name: "toContainEqual", fn: "toContainEqual", length: 1),
    `prop`(name: "toEqual", fn: "toEqual", length: 1),
    `prop`(name: "toMatch", fn: "toMatch", length: 1),
    `prop`(name: "toMatchObject", fn: "toMatchObject", length: 1),
    `prop`(name: "toMatchSnapshot", fn: "toMatchSnapshot", length: 1),
    `prop`(name: "toMatchInlineSnapshot", fn: "toMatchInlineSnapshot", length: 1),
    `prop`(name: "toStrictEqual", fn: "toStrictEqual", length: 1),
    `prop`(name: "toThrow", fn: "toThrow", length: 1),
    `prop`(name: "toThrowError", fn: "toThrow", length: 1),
    `prop`(name: "toThrowErrorMatchingSnapshot", fn: "toThrowErrorMatchingSnapshot", length: 1),
    `prop`(name: "toThrowErrorMatchingInlineSnapshot", fn: "toThrowErrorMatchingInlineSnapshot", length: 1),
    `prop`(name: "toBeOneOf", fn: "toBeOneOf", length: 1),
    getter(name: "not", getterName: "getNot", this_: true, cache: false),
    getter(name: "resolves", getterName: "getResolves", this_: true, cache: false),
    getter(name: "rejects", getterName: "getRejects", this_: true, cache: false),
    `prop`(name: "toBeEmpty", fn: "toBeEmpty", length: 0),
    `prop`(name: "toBeEmptyObject", fn: "toBeEmptyObject", length: 0),
    `prop`(name: "toBeEven", fn: "toBeEven", length: 0),
    `prop`(name: "toBeOdd", fn: "toBeOdd", length: 0),
    `prop`(name: "toBeNil", fn: "toBeNil", length: 0),
    `prop`(name: "toBeArray", fn: "toBeArray", length: 0),
    `prop`(name: "toBeArrayOfSize", fn: "toBeArrayOfSize", length: 1),
    `prop`(name: "toBeBoolean", fn: "toBeBoolean", length: 0),
    `prop`(name: "toBeTrue", fn: "toBeTrue", length: 0),
    `prop`(name: "toBeTypeOf", fn: "toBeTypeOf", length: 1),
    `prop`(name: "toBeFalse", fn: "toBeFalse", length: 0),
    `prop`(name: "toBeNumber", fn: "toBeNumber", length: 0),
    `prop`(name: "toBeInteger", fn: "toBeInteger", length: 0),
    `prop`(name: "toBeObject", fn: "toBeObject", length: 0),
    `prop`(name: "toBeFinite", fn: "toBeFinite", length: 0),
    `prop`(name: "toBePositive", fn: "toBePositive", length: 0),
    `prop`(name: "toBeNegative", fn: "toBeNegative", length: 0),
    `prop`(name: "toBeWithin", fn: "toBeWithin", length: 2),
    `prop`(name: "toEqualIgnoringWhitespace", fn: "toEqualIgnoringWhitespace", length: 1),
    `prop`(name: "toBeSymbol", fn: "toBeSymbol", length: 0),
    `prop`(name: "toBeFunction", fn: "toBeFunction", length: 0),
    `prop`(name: "toBeDate", fn: "toBeDate", length: 0),
    `prop`(name: "toBeValidDate", fn: "toBeValidDate", length: 0),
    `prop`(name: "toBeString", fn: "toBeString", length: 0),
    `prop`(name: "toInclude", fn: "toInclude", length: 1),
    `prop`(name: "toIncludeRepeated", fn: "toIncludeRepeated", length: 2),
    `prop`(name: "toSatisfy", fn: "toSatisfy", length: 1),
    `prop`(name: "toStartWith", fn: "toStartWith", length: 1),
    `prop`(name: "toEndWith", fn: "toEndWith", length: 1)
])

public let expectTypeOfProtoDefinitions: ArrayList<BindClassPropertyDef> = ArrayList<BindClassPropertyDef>([
    `prop`(name: "toBeAny", fn: "fnOneArgumentReturnsVoid", length: 1),
    `prop`(name: "toBeUnknown", fn: "fnOneArgumentReturnsVoid", length: 1),
    `prop`(name: "toBeNever", fn: "fnOneArgumentReturnsVoid", length: 1),
    `prop`(name: "toBeFunction", fn: "fnOneArgumentReturnsVoid", length: 1),
    `prop`(name: "toBeObject", fn: "fnOneArgumentReturnsVoid", length: 1),
    `prop`(name: "toBeArray", fn: "fnOneArgumentReturnsVoid", length: 1),
    `prop`(name: "toBeNumber", fn: "fnOneArgumentReturnsVoid", length: 1),
    `prop`(name: "toBeString", fn: "fnOneArgumentReturnsVoid", length: 1),
    `prop`(name: "toBeBoolean", fn: "fnOneArgumentReturnsVoid", length: 1),
    `prop`(name: "toBeVoid", fn: "fnOneArgumentReturnsVoid", length: 1),
    `prop`(name: "toBeSymbol", fn: "fnOneArgumentReturnsVoid", length: 1),
    `prop`(name: "toBeNull", fn: "fnOneArgumentReturnsVoid", length: 1),
    `prop`(name: "toBeUndefined", fn: "fnOneArgumentReturnsVoid", length: 1),
    `prop`(name: "toBeBigInt", fn: "fnOneArgumentReturnsVoid", length: 1),
    `prop`(name: "toBeCallableWith", fn: "fnOneArgumentReturnsVoid", length: 1),
    `prop`(name: "toBeConstructibleWith", fn: "fnOneArgumentReturnsVoid", length: 1),
    `prop`(name: "extract", fn: "fnOneArgumentReturnsVoid", length: 1),
    `prop`(name: "exclude", fn: "fnOneArgumentReturnsVoid", length: 1),
    `prop`(name: "pick", fn: "fnOneArgumentReturnsVoid", length: 1),
    `prop`(name: "omit", fn: "fnOneArgumentReturnsVoid", length: 1),
    `prop`(name: "parameter", fn: "fnOneArgumentReturnsVoid", length: 1),
    getter(name: "parameters", getterName: "getReturnsExpectTypeOf", this_: false, cache: false),
    getter(name: "constructorParameters", getterName: "getReturnsExpectTypeOf", this_: false, cache: false),
    getter(name: "thisParameter", getterName: "getReturnsExpectTypeOf", this_: false, cache: false),
    getter(name: "instance", getterName: "getReturnsExpectTypeOf", this_: false, cache: false),
    getter(name: "returns", getterName: "getReturnsExpectTypeOf", this_: false, cache: false),
    getter(name: "resolves", getterName: "getReturnsExpectTypeOf", this_: false, cache: false),
    getter(name: "items", getterName: "getReturnsExpectTypeOf", this_: false, cache: false),
    getter(name: "guards", getterName: "getReturnsExpectTypeOf", this_: false, cache: false),
    getter(name: "asserts", getterName: "getReturnsExpectTypeOf", this_: false, cache: false),
    `prop`(name: "toMatchObjectType", fn: "fnOneArgumentReturnsVoid", length: 1),
    `prop`(name: "toExtend", fn: "fnOneArgumentReturnsVoid", length: 1),
    `prop`(name: "toEqualTypeOf", fn: "fnOneArgumentReturnsVoid", length: 1),
    `prop`(name: "toMatchTypeOf", fn: "fnOneArgumentReturnsVoid", length: 1),
    `prop`(name: "toHaveProperty", fn: "fnOneArgumentReturnsVoid", length: 1),
    `prop`(name: "map", fn: "fnOneArgumentReturnsExpectTypeOf", length: 1),
    getter(name: "not", getterName: "getReturnsExpectTypeOf", this_: false, cache: false),
    getter(name: "branded", getterName: "getReturnsExpectTypeOf", this_: false, cache: false)
])
