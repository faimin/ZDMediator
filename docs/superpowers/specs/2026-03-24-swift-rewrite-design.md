# ZDMediator Swift 重写设计文档

**日期：** 2026-03-24
**分支：** feature/swift
**版本目标：** 0.5.0

---

## 背景与目标

将 ZDMediator pod（`Sources/Classes/`）的核心逻辑从 Objective-C 重写为 Swift 6.2，在保持全部 ObjC 调用方零改动的前提下，充分利用 Swift 特性提升可维护性与类型安全。

**约束条件：**
- Swift 6.2，严格并发检查（`.swiftLanguageVersion(.v6)`）
- 最低部署目标：iOS 13、macOS 14
- `NSMutableOrderedSet` 替换为 ReerKit 的 `OrderedSet`（复制单文件，不引入整个库）
- ObjC 调用代码零迁移成本（通过 `@objc(ZDMOneForAll)` 等名称映射保证）
- 支持 CocoaPods 和 Swift Package Manager

---

## 方案选择

在三种方案（保守拆分 / 务实分层 / 最大化 Swift）中，选择**方案 B：务实分层**。

**核心原则：**
- Swift 负责所有可用 Swift 表达的逻辑（数据模型、状态管理、注册/查找核心流程、section 读取）
- ObjC 只保留技术上无法被 Swift 替代的部分（NSProxy 子类、NSInvocation + @encode、nil-terminated 变参接口、C 宏注册）
- 不引入任何新的外部依赖

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
│       ├── Public/
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
        .tvOS(.v12),
        .watchOS(.v5),
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
            publicHeadersPath: "Classes",
            cSettings: [
                .headerSearchPath("Classes/ObjC/Public"),
                .headerSearchPath("Classes/ObjC/Tools"),
                .headerSearchPath("Classes/ObjC/Private"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("SymbolLinkageMarkers"),
                .swiftLanguageVersion(.v6),
            ]
        ),
    ]
)
```

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
    var isAllClassMethods: Bool
    var priority: Int
}
```

### `ServiceInstance`（原 `ZDMServiceItem`）

```swift
final class ServiceInstance {
    private var _strong: AnyObject?
    private weak var _weak: AnyObject?

    var obj: AnyObject? { _strong ?? _weak }

    func store(_ obj: AnyObject, weak: Bool) {
        // 替换时通知旧实例 zdm_willDispose
        if weak { _weak = obj } else { _strong = obj }
    }
    func clear() { _strong = nil; _weak = nil }
}
```

### `EventResponder`（原 `ZDMEventResponder`）

```swift
struct EventResponder: Hashable {
    let serviceName: String
    let priority: Int

    // 等值判断只看 serviceName（与原 OC isEqual: 行为一致）
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.serviceName == rhs.serviceName }
    func hash(into hasher: inout Hasher) {
        hasher.combine(serviceName)
        hasher.combine(priority)
    }
}
```

### `MediatorServiceProtocol`（原 `ZDMCommonProtocol`）

```swift
@objc(ZDMCommonProtocol)
public protocol MediatorServiceProtocol: NSObjectProtocol {
    @objc optional static func zdm_priority() -> Int
    @objc optional static func zdm_createInstance(_ context: MediatorContext?) -> Self
    @objc optional func zdm_setup()
    @objc optional func zdm_willDispose()
    @objc optional func zdm_handleEvent(
        _ event: Int,
        userInfo: Any?,
        callback: ZDMCommonCallback?
    ) -> Bool
}
```

> `ZDMCommonCallback` 仍定义在 `ZDMediatorDefine.h`，通过桥接头文件引用。

---

## Macho Section 注册体系

### Section 格式（ObjC 与 Swift 共用）

写入 `__DATA,__ZDMKV_OFA`，使用 C 兼容双指针结构：

```c
// ZDMediatorDefine.h
typedef struct {
    const char * _Nonnull protocol_name;
    const char * _Nonnull class_name;
} ZDMMachoKVEntry;
```

Swift 读取时映射为 `(UnsafePointer<CChar>, UnsafePointer<CChar>)`，内存布局完全兼容。

### ObjC 侧注册（C 宏，用法不变）

```c
// ZDMediatorDefine.h
#define ZDMediatorOFARegister(protocol, cls) \
    __attribute__((used, section("__DATA,__ZDMKV_OFA"))) \
    static const ZDMMachoKVEntry _zdm_entry_##protocol##_##cls = { \
        #protocol, #cls \
    };
```

### Swift 侧注册（`@_section` + `@_used` 实验特性）

```swift
// MediatorDefine.swift
// 使用方（Swift 模块内）：
@_used @_section("__DATA,__ZDMKV_OFA")
private let _myEntry: (UnsafePointer<CChar>, UnsafePointer<CChar>) = (
    ("MyProtocol" as StaticString).utf8Start,
    ("MyClass" as StaticString).utf8Start
)
```

`StaticString.utf8Start` 指向二进制只读段中的字符串字面量，生命周期与程序相同，安全。

### Section 读取（`SectionReader.swift`）

```swift
import MachO

enum SectionReader {
    typealias SectionEntry = (UnsafePointer<CChar>, UnsafePointer<CChar>)

    static func readKVEntries() -> [(protocolName: String, className: String)] {
        var results: [(String, String)] = []
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
                results.append((String(cString: entry.0), String(cString: entry.1)))
            }
        }
        return results
    }
}
```

### 加载时机

- **懒加载**：`Mediator` 单例 `init()` 调用 `_loadFromSection()`，由 `Bool` flag + `ZDMLock` 保证只执行一次
- **加载流程**：`SectionReader.readKVEntries()` → 逐条调用内部 `register(protocolName:className:priority:autoInit:)` → 写入 `registerInfoDict`

---

## `Mediator` 核心类

### 内部状态

```swift
@objc(ZDMOneForAll)
public final class Mediator: NSObject {

    @objc public static let shared = Mediator()
    private override init() { super.init(); _loadFromSection() }

    // "protocolName-priority" → ServiceRegistration
    private var registerInfoDict:   [String: ServiceRegistration] = [:]
    // className → OrderedSet<"protocolName-priority">
    private var registerClassDict:  [String: OrderedSet<String>] = [:]
    // protocolName → [Int]（降序排列）
    private var priorityDict:       [String: [Int]] = [:]
    // className → ServiceInstance
    private var instanceDict:       [String: ServiceInstance] = [:]
    // eventId / selectorName → OrderedSet<EventResponder>
    private var eventResponderDict: [String: OrderedSet<EventResponder>] = [:]

    private let lock = ZDMLock()

    @objc public private(set) var proxy: AnyObject?   // ZDMBroadcastProxy
    @objc public var context: MediatorContext?
}
```

### 对外注册接口

```swift
// 内部通用注册（Macho 加载 + 手动注册统一入口）
func register(protocolName: String, className: String, priority: Int, autoInit: Bool)

// ObjC 可调用
@objc public static func registerService(_:priority:implementClass:)
@objc public static func manualRegisterService(_:priority:implementer:weakStore:)
```

### 服务获取接口

```swift
@objc public static func service(_:priority:) -> AnyObject?
@objc public static func serviceWithName(_:priority:) -> AnyObject?
@objc public static func serviceWithName(_:priority:onlyFromCache:) -> AnyObject?
@objc public static func removeService(_:priority:autoInitAgain:) -> Bool

// Swift 专用类型安全辅助（MediatorDefine.swift）
public func zdmService<T>(_ type: T.Type, priority: Int = 0) -> T?
```

### 实例创建流程（`_createInstance`）

1. 查 `instanceDict` —— 已有实例直接返回
2. `isAllClassMethods == true` —— 返回 `cls` 本身
3. `cls` 实现 `zdm_createInstance:` —— 调用自定义工厂
4. 否则 `alloc().init()` —— **先写入 `instanceDict` 再 init**（防循环依赖）
5. 调用 `zdm_setup()`
6. **Fault tolerance**：priority 0 找不到时，fallback 到已注册的最高 priority 并打印日志

### 事件系统内部接口（供 ObjC Category 调用）

```swift
@objc func _dispatchToProtocol(_:selector:args:) -> [Any]
@objc func _dispatchToEventId(_:selector:args:) -> [Any]
@objc func _dispatchToSelector(_:args:) -> [Any]
```

---

## ObjC 保留层

### `Mediator+Dispatch.m`

nil-terminated 可变参数方法解析后转发给 Swift：

```objc
+ (NSArray *)dispatchWithProtocol:(Protocol *)protocol selAndArgs:(SEL)sel, ... {
    NSArray *args = /* 用 ZDMInvocation 的 va_list 工具收集参数 */;
    return [[self shared] _dispatchToProtocol:protocol selector:sel args:args];
}
// dispatchWithEventId:selAndArgs:
// dispatchWithEventSelAndArgs:
// dispatchWithSELAndArgs:
```

### 不变的 ObjC 文件

| 文件 | 原因 |
|------|------|
| `ZDMInvocation.h/m` | NSInvocation + @encode，Swift 无等价方案 |
| `ZDMConst.h/m` | 通知名常量，ObjC 代码依赖 |
| `ZDMProxy.h/m` | NSProxy 子类，Swift 无法实现 |
| `ZDMBroadcastProxy.h/m` | 同上 |
| `ZDMediatorDefine.h` | C 宏注册入口，更新 `ZDMMachoKVEntry` 结构体定义 |

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

以下宏保留，内部 `ZDMMachoKVEntry` 结构体更新后用法不变：

```objc
ZDMediatorOFARegister(MyProtocol, MyClass)       // 自动注册，autoInit=YES
ZDMediatorOFARegisterManual(MyProtocol, MyClass) // 手动注册，autoInit=NO
ZDMediator1V1Register(MyProtocol, MyClass)       // 1:1 注册
ZDMGetService(MyProtocol)                        // 获取服务（默认 priority 0）
ZDMGetServiceWithPriority(MyProtocol, 1)
ZDMGetServiceFromCache(MyProtocol)
ZDMGetServiceWithClass(MyProtocol, 0, MyClass)
```

---

## 兼容性保证

- 所有 ObjC 调用点（注册宏、`ZDMGetService` 系列、`dispatchWithXxx:selAndArgs:` 等）**零改动**
- Swift 调用方获得类型安全的 `zdmService<T>()` 辅助函数
- Podspec 需在 `pod_target_xcconfig` 增加：`OTHER_SWIFT_FLAGS = -enable-experimental-feature SymbolLinkageMarkers`
