# ZDMediator Swift 重写设计文档

**日期：** 2026-03-24
**分支：** feature/swift
**版本目标：** 0.5.0（Breaking change：Macho section 格式更新，需重新编译所有注册方）

---

## 背景与目标

将 ZDMediator pod（`Sources/Classes/`）的核心逻辑从 Objective-C 重写为 Swift 6.2，在保持全部 ObjC 调用方零改动的前提下，充分利用 Swift 特性提升可维护性与类型安全。

**约束条件：**
- Swift 6.2，严格并发检查（`.swiftLanguageVersion(.v6)`）
- 最低部署目标：iOS 13、macOS 14、tvOS 16、watchOS 9（均为 64-bit only，显式放弃 32-bit 支持）
- `NSMutableOrderedSet` 替换为 ReerKit 的 `OrderedSet`（复制单文件，不引入整个库）
- ObjC 调用代码零迁移成本（通过 `@objc(ZDMOneForAll)` 等名称映射保证）
- 支持 CocoaPods 和 Swift Package Manager
- 不引入任何新的外部依赖

---

## 方案选择

在三种方案（保守拆分 / 务实分层 / 最大化 Swift）中，选择**方案 B：务实分层**。

**核心原则：**
- Swift 负责所有可用 Swift 表达的逻辑（数据模型、状态管理、注册/查找核心流程、section 读取）
- ObjC 只保留技术上无法被 Swift 替代的部分（NSProxy 子类、NSInvocation + @encode、nil-terminated 变参接口、C 宏注册）
- dispatch 循环（遍历服务实例、调用 `ZDMInvocation`）保留在 ObjC Category 中，Swift 只提供有序服务列表查询接口（Option B 架构，避免 `[Any]` → `va_list` 转换问题）

---

## 文件结构

```
Sources/
├── Classes/
│   ├── Swift/
│   │   ├── Public/
│   │   │   ├── Mediator.swift                  # 核心单例，@objc(ZDMOneForAll)
│   │   │   ├── MediatorContext.swift            # @objc(ZDMContext)
│   │   │   ├── MediatorServiceProtocol.swift    # @objc protocol ZDMCommonProtocol
│   │   │   └── MediatorDefine.swift             # Swift 侧类型别名、@_section 注册辅助
│   │   ├── Private/
│   │   │   ├── ServiceRegistration.swift        # 原 ZDMServiceBox
│   │   │   ├── ServiceInstance.swift            # 原 ZDMServiceItem
│   │   │   ├── EventResponder.swift             # 原 ZDMEventResponder
│   │   │   └── ZDMLock.swift                   # 锁封装（NSRecursiveLock，后续可替换）
│   │   └── Tools/
│   │       ├── SectionReader.swift             # Macho section 读取（自实现，无依赖）
│   │       ├── OrderedSet.swift                # 从 ReerKit 复制的 OrderedSet
│   │       └── NSObject+OnDealloc.swift        # dealloc 回调扩展
│   │
│   └── ObjC/
│       ├── Public/                              # SPM publicHeadersPath 指向此目录
│       │   ├── ZDMediator.h                    # umbrella header（不变）
│       │   ├── ZDMediatorDefine.h              # C 宏注册 + ZDMMachoKVEntry 结构体
│       │   ├── ZDMProxy.h / .m                # NSProxy 子类（不可 Swift 化）
│       │   └── ZDMBroadcastProxy.h / .m       # NSProxy 广播子类（不可 Swift 化）
│       ├── Private/
│       │   └── Mediator+Dispatch.h / .m        # nil-terminated 变参 dispatch（ObjC Category）
│       └── Tools/
│           ├── ZDMInvocation.h / .m            # NSInvocation + @encode（保留不变）
│           └── ZDMConst.h / .m                # 通知名常量（保留不变）
│
├── Assets/
└── Resource/
    └── PrivacyInfo.xcprivacy
```

**删除的文件（功能迁移至 Swift）：**
- `ZDMOneForAll.h / .m` → `Mediator.swift`
- `ZDMOneForAll+Private.h` → Swift 访问控制替代
- `ZDMServiceBox.h / .m` → `ServiceRegistration.swift`
- `ZDMServiceItem.h / .m` → `ServiceInstance.swift`
- `ZDMEventResponder.h / .m` → `EventResponder.swift`
- `ZDMLock.h / .m` → `ZDMLock.swift`
- `ZDMContext.h / .m` → `MediatorContext.swift`
- `ZDMCommonProtocol.h` → `MediatorServiceProtocol.swift`
- `NSObject+ZDMOnDealloc.h / .m` → `NSObject+OnDealloc.swift`

---

## Package.swift 更新

```swift
// swift-tools-version: 6.0
let package = Package(
    name: "ZDMediator",
    platforms: [
        .iOS(.v13),
        .macOS(.v14),
        .tvOS(.v16),
        .watchOS(.v9),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "ZDMediator", targets: ["ZDMediator"]),
    ],
    targets: [
        .target(
            name: "ZDMediator",
            path: "Sources",
            resources: [.process("Resource/PrivacyInfo.xcprivacy")],
            publicHeadersPath: "Classes/ObjC/Public",   // 仅暴露 ObjC 公共头文件
            cSettings: [
                .headerSearchPath("Classes/ObjC/Public"),
                .headerSearchPath("Classes/ObjC/Tools"),
                .headerSearchPath("Classes/ObjC/Private"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("SymbolLinkageMarkers"),  // 支持 @_section + @_used
                .swiftLanguageVersion(.v6),
            ]
        ),
    ]
)
```

> **SPM 混编说明：** ObjC Category 文件（`Mediator+Dispatch.m`）通过 `#import "ZDMediator-Swift.h"` 引用 Swift 生成头文件。SPM 在混编 target 中自动生成该头文件，路径由编译器注入，无需桥接头文件。

---

## 核心数据类型

### `MediatorContext`（原 `ZDMContext`）

```swift
@objc(ZDMContext)
public final class MediatorContext: NSObject {
    @objc public var launchOptions: [AnyHashable: Any]?
    @objc public var extraObj: AnyObject?
}
```

### `ServiceRegistration`（原 `ZDMServiceBox`）

```swift
final class ServiceRegistration {
    unowned(unsafe) let cls: AnyClass
    let protocolName: String
    var autoInit: Bool
    var isAllClassMethods: Bool   // 运行时检测，非 section 字段
    var priority: Int             // 来自 zdm_priority() 或默认 0，非 section 字段
}
```

### `ServiceInstance`（原 `ZDMServiceItem`）

```swift
final class ServiceInstance {
    private var _strong: AnyObject?
    private weak var _weak: AnyObject?

    var obj: AnyObject? { _strong ?? _weak }

    func store(_ newObj: AnyObject, weak: Bool) {
        // 替换前通知旧实例
        let old = _strong ?? _weak
        if let disposable = old as? MediatorServiceProtocol {
            disposable.zdm_willDispose?()
        }
        if weak { _weak = newObj; _strong = nil }
        else { _strong = newObj; _weak = nil }
    }

    func clear() {
        let old = _strong ?? _weak
        if let disposable = old as? MediatorServiceProtocol {
            disposable.zdm_willDispose?()
        }
        _strong = nil; _weak = nil
    }
}
```

### `EventResponder`（原 `ZDMEventResponder`）

```swift
struct EventResponder: Hashable {
    let serviceName: String
    let priority: Int

    // 等值判断只看 serviceName（与原 OC isEqual: 行为一致）
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.serviceName == rhs.serviceName }

    // hash 只结合参与 == 的字段，满足 Hashable 契约
    func hash(into hasher: inout Hasher) {
        hasher.combine(serviceName)
    }
}
```

> **注意：** 原 OC 的 `hash` 用 `serviceName.hash ^ priority` 违反了 `NSHashTable` 的契约（幸运地因 OC 容器回退到 `isEqual:` 而未崩溃）。Swift `Set`/`OrderedSet` 严格依赖 hash，此处必须修正。

### `MediatorServiceProtocol`（原 `ZDMCommonProtocol`）

```swift
@objc(ZDMCommonProtocol)
public protocol MediatorServiceProtocol: NSObjectProtocol {
    @objc optional static func zdm_priority() -> Int
    // 返回 AnyObject? 而非 Self，以兼容 @objc（Self 在 @objc 中不可表示）
    @objc optional static func zdm_createInstance(_ context: MediatorContext?) -> AnyObject
    @objc optional func zdm_setup()
    @objc optional func zdm_willDispose()
    @objc optional func zdm_handleEvent(
        _ event: Int,
        userInfo: Any?,
        callback: ZDMCommonCallback?
    ) -> Bool
}
```

> `ZDMCommonCallback` 仍定义在 `ZDMediatorDefine.h`，通过 SPM 自动生成的桥接头文件引用。

---

## Macho Section 注册体系

### Section 格式（ObjC 与 Swift 共用）

**Breaking Change（版本 0.5.0）：** 原 5 字段结构体（含 `priority`、`allClsMethod`、`autoInit`）简化为 3 字段。`priority` 和 `isAllClassMethods` 改为运行时从类自身获取，减少 section 数据量。

```c
// ZDMediatorDefine.h（更新后）
typedef struct {
    const char * _Nonnull protocol_name;  // 8 bytes
    const char * _Nonnull class_name;     // 8 bytes
    int32_t      auto_init;               // 4 bytes（1=autoInit, 0=manual）
    int32_t      _padding;                // 4 bytes（对齐到 24 bytes）
} ZDMMachoKVEntry;
```

所有使用旧结构体格式（5 字段）编译的 `.o` 文件必须重新编译。这是一个硬性断点，版本号从 0.4.x 升至 0.5.0。

Swift 读取时映射为对应的 `@frozen` struct：

```swift
// SectionReader.swift 内部
@frozen
struct SectionEntry {
    let protocolNamePtr: UnsafePointer<CChar>
    let classNamePtr: UnsafePointer<CChar>
    let autoInit: Int32
    let _padding: Int32
}
// MemoryLayout<SectionEntry>.size == 24，与 ZDMMachoKVEntry 完全一致
```

使用 `@frozen` struct（非匿名 tuple）确保跨编译器版本的内存布局稳定性。

### ObjC 侧注册（C 宏，用法不变）

```c
// ZDMediatorDefine.h
#define ZDMediatorOFARegister(protocol, cls) \
    __attribute__((used, section("__DATA,__ZDMKV_OFA"))) \
    static const ZDMMachoKVEntry _zdm_kv_##protocol##_##cls = { \
        #protocol, #cls, 1, 0 \
    };

#define ZDMediatorOFARegisterManual(protocol, cls) \
    __attribute__((used, section("__DATA,__ZDMKV_OFA"))) \
    static const ZDMMachoKVEntry _zdm_kv_manual_##protocol##_##cls = { \
        #protocol, #cls, 0, 0 \
    };
```

### Swift 侧注册（`@_section` + `@_used` 实验特性）

```swift
// MediatorDefine.swift 中提供辅助函数，简化使用方写法
// 使用方（Swift 模块内）：
@_used @_section("__DATA,__ZDMKV_OFA")
private let _myEntry = SectionEntry(
    protocolNamePtr: ("MyProtocol" as StaticString).utf8Start,
    classNamePtr: ("MyClass" as StaticString).utf8Start,
    autoInit: 1,
    _padding: 0
)
```

**StaticString 安全性：** `utf8Start` 仅在 `hasPointerRepresentation == true` 时有效。对于 ASCII 协议名/类名，此条件必然成立。实现时加 `precondition(str.hasPointerRepresentation)` 保护。

### Section 读取（`SectionReader.swift`）

```swift
import MachO

enum SectionReader {
    // 64-bit only（最低系统版本已排除所有 32-bit 设备）
    static func readKVEntries() -> [(protocolName: String, className: String, autoInit: Bool)] {
        var results: [(String, String, Bool)] = []
        let imageCount = _dyld_image_count()
        for i in 0..<imageCount {
            guard let header = _dyld_get_image_header(i) else { continue }
            guard header.pointee.magic == MH_MAGIC_64 else { continue }
            var size: UInt = 0
            guard let ptr = getsectiondata(
                UnsafeRawPointer(header).assumingMemoryBound(to: mach_header_64.self),
                "__DATA", "__ZDMKV_OFA", &size
            ) else { continue }
            let count = Int(size) / MemoryLayout<SectionEntry>.stride
            let buffer = UnsafeBufferPointer(
                start: ptr.assumingMemoryBound(to: SectionEntry.self),
                count: count
            )
            for entry in buffer {
                results.append((
                    String(cString: entry.protocolNamePtr),
                    String(cString: entry.classNamePtr),
                    entry.autoInit != 0
                ))
            }
        }
        return results
    }
}
```

> **32-bit 说明：** 最低部署目标（iOS 13 / macOS 14 / tvOS 16 / watchOS 9）已不含任何 32-bit 设备，`MH_MAGIC_64` 检查用于安全过滤，不需要 32-bit 路径。

> **内存布局断言：** 实现时加入编译期断言防止字段变更导致 layout 漂移：
> ```swift
> private let _layoutCheck: Void = {
>     assert(MemoryLayout<SectionEntry>.size == 24)
>     assert(MemoryLayout<SectionEntry>.stride == 24)
>     assert(MemoryLayout<SectionEntry>.alignment == 8)
> }()
> ```

### 加载时机（懒加载，与现有行为一致）

```swift
// Mediator.swift 内部
private var _sectionLoaded = false  // 受 lock 保护

// 所有公共 service 查询方法入口调用
private func _loadSectionIfNeeded() {
    lock.withLock {
        guard !_sectionLoaded else { return }
        _sectionLoaded = true
        let entries = SectionReader.readKVEntries()
        for e in entries {
            _register(protocolName: e.protocolName,
                      className: e.className,
                      autoInit: e.autoInit)
        }
    }
}
```

`init()` 中**不**调用加载，首次访问服务时触发，与原 OC `dispatch_once` 懒加载逻辑一致。

---

## `Mediator` 核心类

### 类声明与 Sendable

```swift
@objc(ZDMOneForAll)
public final class Mediator: NSObject, @unchecked Sendable {
    // @unchecked Sendable：内部状态完全由 ZDMLock 保护，手动保证线程安全

    @objc public static let shared = Mediator()
    private override init() { super.init() }
    // 注意：init 中不做 section 加载，懒加载在首次服务访问时触发

    // MARK: - 内部状态（全部由 lock 保护）

    /// "protocolName-priority" → ServiceRegistration
    private var registerInfoDict:   [String: ServiceRegistration] = [:]
    /// className → Set<"protocolName-priority">（O(1) contains，无需有序）
    private var registerClassDict:  [String: Set<String>] = [:]
    /// protocolName → [Int]（降序排列，方便 fallback 查找）
    private var priorityDict:       [String: [Int]] = [:]
    /// className → ServiceInstance（同一个类只创建一个实例）
    private var instanceDict:       [String: ServiceInstance] = [:]
    /// eventId/selectorName → OrderedSet<EventResponder>
    private var eventResponderDict: [String: OrderedSet<EventResponder>] = [:]

    private let lock = ZDMLock()
    private var _sectionLoaded = false

    @objc public private(set) var proxy: AnyObject?   // ZDMBroadcastProxy 实例
    @objc public var context: MediatorContext?
}
```

### 对外注册接口

```swift
// 内部通用注册（Macho 加载 + 手动注册统一入口）
private func _register(protocolName: String, className: String, autoInit: Bool)

// ObjC 可调用（保持原签名）
@objc public static func registerService(_ protocol: Protocol, priority: Int, implementClass cls: AnyClass)
@objc public static func manualRegisterService(_ protocol: Protocol, priority: Int,
                                               implementer: AnyObject, weakStore: Bool)
```

### 服务获取接口

```swift
@objc public static func service(_ protocol: Protocol, priority: Int) -> AnyObject?
@objc public static func serviceWithName(_ name: String, priority: Int) -> AnyObject?
@objc public static func serviceWithName(_ name: String, priority: Int, onlyFromCache: Bool) -> AnyObject?
@objc public static func removeService(_ protocol: Protocol, priority: Int, autoInitAgain: Bool) -> Bool

// 调试接口（保持现有公共 API）
@objc public static func allInitializedObjects() -> NSHashTable<AnyObject>
@objc public static func allRegisterClasses() -> NSOrderedSet  // NSOrderedSet<Class>

// Swift 专用类型安全辅助（MediatorDefine.swift）
public func zdmService<T>(_ type: T.Type, priority: Int = 0) -> T?
```

### 实例创建流程（`_createInstance`）

1. 查 `instanceDict` —— 已有实例直接返回（`lock` 内）
2. `isAllClassMethods == true` —— 返回 `cls` 本身，不创建实例
3. `cls` 实现 `zdm_createInstance:` —— 调用自定义工厂方法
4. 否则 `cls.alloc().init()` —— **先占位写入 `instanceDict` 再调 `init()`**（防循环依赖）
5. 调用 `zdm_setup()`
6. **ZDMProxy 包装**：`service(_:priority:)` 在返回前判断是否需要 proxy 包装（`needProxyWrap`），若需要则返回 `ZDMProxy(target:)` 而非原始实例
7. **Fault tolerance**：priority 0 找不到时，fallback 到 `priorityDict` 中最高 priority 并打印日志

### Dispatch 接口（Option B 架构）

ObjC Category 中保留完整的 dispatch 循环，Swift 只提供有序服务列表查询：

```swift
// Swift 提供：查询有序服务实例列表（供 Mediator+Dispatch.m 调用）
@objc func _serviceInstances(forProtocol proto: Protocol) -> [AnyObject]
@objc func _serviceInstances(forEventId eventId: String) -> [AnyObject]
@objc func _serviceInstances(forSelector sel: Selector) -> [AnyObject]
@objc func _allServiceInstancesRespondingTo(selector sel: Selector) -> [AnyObject]
```

`Mediator+Dispatch.m` 获取实例列表后，自行调用 `ZDMInvocation` 完成动态派发，收集返回值，与原 dispatch 逻辑完全一致。

---

## ObjC 保留层

### `Mediator+Dispatch.m`（架构调整）

```objc
// Option B：ObjC 持有完整 dispatch 循环
// 注意：va_list 必须在每次循环内独立声明并 va_start/va_end（与原 ZDMOneForAll.m 一致）
// 在已初始化但未 va_end 的 va_list 上调用 va_start 是 C UB（ARM64 ABI 不可移植）
+ (NSArray *)dispatchWithProtocol:(Protocol *)protocol selAndArgs:(SEL)sel, ... {
    NSArray *targets = [[self shared] _serviceInstancesForProtocol:protocol];
    NSMutableArray *results = [NSMutableArray array];
    for (id target in targets) {
        va_list args;
        va_start(args, sel);
        id ret = [ZDMInvocation target:target invokeSelector:sel args:args];
        va_end(args);
        if (ret) [results addObject:ret];
    }
    return results;
}
// 其余三个 dispatch 方法（dispatchWithEventId:、dispatchWithEventSelAndArgs:、
// dispatchWithSELAndArgs:）采用完全相同的 va_list 模式
```

### 不变的 ObjC 文件

| 文件 | 原因 |
|------|------|
| `ZDMInvocation.h/m` | NSInvocation + @encode，Swift 无等价方案 |
| `ZDMConst.h/m` | 通知名常量，ObjC 代码依赖 |
| `ZDMProxy.h/m` | NSProxy 子类，Swift 无法实现 |
| `ZDMBroadcastProxy.h/m` | 同上 |
| `ZDMediatorDefine.h` | C 宏注册入口，更新 `ZDMMachoKVEntry` 结构体为 3 字段 |

**`ZDMediator.h` 需更新：** 删除对已移除 ObjC 文件的 `#import`（`ZDMOneForAll.h`、`ZDMContext.h`、`ZDMCommonProtocol.h` 等），改为 `#import "ZDMediator-Swift.h"`（SPM/framework 编译时自动生成）或由实现时按实际生成路径调整。

---

## 工具层

### `ZDMLock.swift`

```swift
final class ZDMLock: @unchecked Sendable {
    private let _lock = NSRecursiveLock()
    func lock()   { _lock.lock() }
    func unlock() { _lock.unlock() }
    @discardableResult
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        _lock.lock(); defer { _lock.unlock() }
        return try body()
    }
}
```

### `NSObject+OnDealloc.swift`

> **API 变更说明：** 原 ObjC 版本的 block 类型为 `ZDM_DisposeBlock`（`void(^)(id _Nullable realTarget)`）。Swift 版本简化为无参 block `() -> Void`，对应 ObjC 导出为 `void(^)(void)`。
>
> 这是一个 **ObjC 源码级 breaking change**：已有传入带参数 block 的调用方会得到类型不匹配警告/错误。需同步更新 `ZDMediatorDefine.h` 中的 `ZDM_DisposeBlock` typedef 为 `void(^)(void)`，并将框架内所有调用点从 `^(id realTarget){...}` 改为 `^{...}`。

```swift
private final class DeallocExecutor: NSObject {
    let block: () -> Void
    init(_ block: @escaping () -> Void) { self.block = block }
    deinit { block() }
}
private var deallocKey: UInt8 = 0

extension NSObject {
    @objc public func zdm_onDealloc(_ block: @escaping () -> Void) {
        var executors = objc_getAssociatedObject(self, &deallocKey) as? [DeallocExecutor] ?? []
        executors.append(DeallocExecutor(block))
        objc_setAssociatedObject(self, &deallocKey, executors, .OBJC_ASSOCIATION_RETAIN)
    }
}
```

---

## ObjC 宏（快捷注册，供 ObjC 类使用）

以下宏对外用法不变，内部 `ZDMMachoKVEntry` 更新为 3 字段格式：

```objc
ZDMediatorOFARegister(MyProtocol, MyClass)       // 自动注册，autoInit=1
ZDMediatorOFARegisterManual(MyProtocol, MyClass) // 手动注册，autoInit=0
ZDMediator1V1Register(MyProtocol, MyClass)       // 1:1 注册
ZDMGetService(MyProtocol)                        // 获取服务（默认 priority 0）
ZDMGetServiceWithPriority(MyProtocol, 1)
ZDMGetServiceFromCache(MyProtocol)
ZDMGetServiceWithClass(MyProtocol, 0, MyClass)
```

---

## Podspec 更新

```ruby
Pod::Spec.new do |s|
  s.subspec 'Tools' do |ss|
    ss.source_files = 'Sources/Classes/ObjC/Tools/*.{h,m}',
                      'Sources/Classes/Swift/Tools/*.swift'
  end

  s.subspec 'Mediator' do |ss|
    ss.dependency 'ZDMediator/Tools'
    ss.source_files = 'Sources/Classes/ObjC/**/*.{h,m}',
                      'Sources/Classes/Swift/**/*.swift'
    ss.public_header_files = 'Sources/Classes/ObjC/Public/*.h'
    ss.pod_target_xcconfig = {
      'OTHER_SWIFT_FLAGS' => '-enable-experimental-feature SymbolLinkageMarkers'
    }
  end

  s.subspec 'EnableAssert' do |ss|
    ss.dependency 'ZDMediator/Mediator'
    ss.pod_target_xcconfig = {
      'GCC_PREPROCESSOR_DEFINITIONS' => 'ENABLE_ASSERT=1',
      'OTHER_SWIFT_FLAGS' => '-enable-experimental-feature SymbolLinkageMarkers'
    }
  end
end
```

---

## 兼容性保证

- 所有 ObjC 调用点（注册宏、`ZDMGetService` 系列、`dispatchWithXxx:selAndArgs:` 等）**零改动**
- Swift 调用方获得类型安全的 `zdmService<T>()` 辅助函数
- `allInitializedObjects()` 和 `allRegisterClasses()` 公共调试 API 完整保留
- **版本 0.5.0 Breaking Change：** `ZDMMachoKVEntry` 从 5 字段变为 3 字段，所有使用注册宏的文件需重新编译（不需要修改代码）
- **`ZDM_DisposeBlock` 类型变更：** 从 `void(^)(id)` 改为 `void(^)(void)`，框架内部调用点需将 `^(id realTarget){...}` 改为 `^{...}`
- **`_loadSectionIfNeeded` 性能说明：** 首次服务访问时持锁遍历所有 dyld 镜像（通常 < 1ms），属于一次性开销，为简化实现的有意权衡
