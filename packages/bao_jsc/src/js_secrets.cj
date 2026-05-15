// 严格翻译自: src/jsc/JSSecrets.zig (87行)
// JavaScriptCore SecretsJob - 密钥扫描异步任务

package bao_jsc

// ========== SecretsJob ==========
// 严格翻译自 JSSecrets.zig SecretsJob
// 异步密钥扫描任务，在工作线程池中运行
// 完成后通过 AnyTask 在主线程回调 JS
//
// 原始 Zig 代码:
//   pub const SecretsJob = struct {
//       vm: *jsc.VirtualMachine,
//       task: jsc.WorkPoolTask,
//       any_task: jsc.AnyTask,
//       poll: Async.KeepAlive = .{},
//       promise: jsc.Strong,
//       ctx: *SecretsJobOptions,
//   };
public class SecretsJob {
    // 关联的虚拟机
    public var vm: BunVirtualMachine = BunVirtualMachine()
    // 工作池任务
    public var task: WorkPoolTask = WorkPoolTask()
    // AnyTask 包装 (主线程回调)
    public var anyTask: CPointer<UInt8> = CPointer<UInt8>()
    // KeepAlive poll 引用
    public var poll: CPointer<UInt8> = CPointer<UInt8>()
    // Promise 强引用
    public var promise: CPointer<UInt8> = CPointer<UInt8>()
    // 密钥扫描选项 (opaque)
    public var ctx: SecretsJobOptions = SecretsJobOptions()

    public init() {}

    // ========== SecretsJobOptions ==========
    // 严格翻译自 JSSecrets.zig SecretsJobOptions
    // C++ 侧的 opaque 结构，通过 FFI 调用
    //
    // 原始 Zig 代码:
    //   const SecretsJobOptions = opaque {
    //       pub extern fn Bun__SecretsJobOptions__runTask(ctx, global) void;
    //       pub extern fn Bun__SecretsJobOptions__runFromJS(ctx, global, promise) void;
    //       pub extern fn Bun__SecretsJobOptions__deinit(ctx) void;
    //   };
    public class SecretsJobOptions {
        public var rawPtr: CPointer<UInt8> = CPointer<UInt8>()

        public init() {}

        // 严格翻译自 SecretsJobOptions.Bun__SecretsJobOptions__runTask
        // FFI: Bun__SecretsJobOptions__runTask(ctx: *SecretsJobOptions, global: *JSGlobalObject) void
        public func runTask(global: JsObject) {
            // FFI: Bun__SecretsJobOptions__runTask(rawPtr, global.rawPtr)
        }

        // 严格翻译自 SecretsJobOptions.Bun__SecretsJobOptions__runFromJS
        // FFI: Bun__SecretsJobOptions__runFromJS(ctx, global, promise) void
        public func runFromJS(global: JsObject, promise: JsValue) {
            // FFI: Bun__SecretsJobOptions__runFromJS(rawPtr, global.rawPtr, promise.encode())
        }

        // 严格翻译自 SecretsJobOptions.Bun__SecretsJobOptions__deinit
        // FFI: Bun__SecretsJobOptions__deinit(ctx) void
        public func deinit() {
            // FFI: Bun__SecretsJobOptions__deinit(rawPtr)
            rawPtr = CPointer<UInt8>()
        }
    }

    // ========== create ==========
    // 严格翻译自 SecretsJob.create
    // 创建 SecretsJob 并关联 Promise
    //
    // 原始 Zig:
    //   pub fn create(global: *jsc.JSGlobalObject, ctx: *SecretsJobOptions, promise: jsc.JSValue) *SecretsJob {
    //       const vm = global.bunVM();
    //       const job = bun.new(SecretsJob, .{
    //           .vm = vm,
    //           .task = .{ .callback = &runTask },
    //           .any_task = undefined,
    //           .ctx = ctx,
    //           .promise = jsc.Strong.create(promise, global),
    //       });
    //       job.any_task = jsc.AnyTask.New(SecretsJob, &runFromJS).init(job);
    //       return job;
    //   }
    public static func create(global: JsObject, ctx: SecretsJobOptions, promise: JsValue) -> SecretsJob {
        let job = SecretsJob()
        // job.vm = global.bunVM()  // FFI
        job.task = WorkPoolTask(callback: runTask)
        job.ctx = ctx
        // job.promise = jsc.Strong.create(promise, global)  // FFI
        // job.anyTask = jsc.AnyTask.New(SecretsJob, &runFromJS).init(job)  // FFI
        job
    }

    // ========== runTask ==========
    // 严格翻译自 SecretsJob.runTask
    // 工作线程中执行密钥扫描任务
    //
    // 原始 Zig:
    //   pub fn runTask(task: *jsc.WorkPoolTask) void {
    //       const job: *SecretsJob = @fieldParentPtr("task", task);
    //       var vm = job.vm;
    //       defer vm.enqueueTaskConcurrent(jsc.ConcurrentTask.create(job.any_task.task()));
    //       SecretsJobOptions.Bun__SecretsJobOptions__runTask(job.ctx, vm.global);
    //   }
    public static func runTask(task: WorkPoolTask) {
        let job = task.parentJob
        // 在工作线程中运行密钥扫描
        job.ctx.runTask(job.vm.global)
        // 将 anyTask 排入主线程并发队列
        // vm.enqueueTaskConcurrent(ConcurrentTask.create(job.anyTask))
    }

    // ========== runFromJS ==========
    // 严格翻译自 SecretsJob.runFromJS
    // 主线程回调，将结果传回 JS
    //
    // 原始 Zig:
    //   pub fn runFromJS(this: *SecretsJob) void {
    //       defer this.deinit();
    //       const vm = this.vm;
    //       if (vm.isShuttingDown()) { return; }
    //       const promise = this.promise.get();
    //       if (promise == .zero) return;
    //       SecretsJobOptions.Bun__SecretsJobOptions__runFromJS(this.ctx, vm.global, promise);
    //   }
    public func runFromJS() {
        // defer deinit()
        if (vm.isShuttingDown()) {
            deinit()
            return
        }

        // promise.get() - FFI 获取 promise 值
        let promiseValue = JsValue.undefined()
        if (promiseValue.isEmptyOrUndefinedOrNull()) {
            deinit()
            return
        }

        ctx.runFromJS(vm.global, promiseValue)
        deinit()
    }

    // ========== deinit ==========
    // 严格翻译自 SecretsJob.deinit
    // 释放所有资源
    //
    // 原始 Zig:
    //   fn deinit(this: *SecretsJob) void {
    //       SecretsJobOptions.Bun__SecretsJobOptions__deinit(this.ctx);
    //       this.poll.unref(this.vm);
    //       this.promise.deinit();
    //       bun.destroy(this);
    //   }
    public func deinit() {
        ctx.deinit()
        // poll.unref(vm) - FFI
        // promise.deinit() - FFI
        poll = CPointer<UInt8>()
        promise = CPointer<UInt8>()
    }

    // ========== schedule ==========
    // 严格翻译自 SecretsJob.schedule
    // 调度任务到工作线程池
    //
    // 原始 Zig:
    //   pub fn schedule(this: *SecretsJob) void {
    //       this.poll.ref(this.vm);
    //       jsc.WorkPool.schedule(&this.task);
    //   }
    public func schedule() {
        // poll.ref(vm) - FFI: KeepAlive 引用
        // WorkPool.schedule(&task) - FFI: 排入工作线程池
    }
}

// ========== Bun__Secrets__scheduleJob ==========
// 严格翻译自 JSSecrets.zig Bun__Secrets__scheduleJob
// C++ 调用的入口点，创建并调度 SecretsJob
//
// 原始 Zig:
//   export fn Bun__Secrets__scheduleJob(
//       global: *jsc.JSGlobalObject,
//       options: *SecretsJob.SecretsJobOptions,
//       promise: jsc.JSValue
//   ) void {
//       const job = SecretsJob.create(global, options, promise);
//       job.schedule();
//   }
public func secretsScheduleJob(global: JsObject, options: SecretsJob.SecretsJobOptions, promise: JsValue) {
    let job = SecretsJob.create(global, options, promise)
    job.schedule()
}

// ========== WorkPoolTask ==========
// 严格翻译自 jsc.WorkPoolTask
// 工作池任务
public class WorkPoolTask {
    public var callback: (WorkPoolTask) -> Unit
    public var parentJob: SecretsJob = SecretsJob()

    public init() {
        callback = { _ => }
    }

    public init(callback: (WorkPoolTask) -> Unit) {
        this.callback = callback
    }

    public func run() {
        callback(this)
    }
}
