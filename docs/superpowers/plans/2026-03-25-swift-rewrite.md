# ZDMediator Swift 重写 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 用 Swift 6.2 重写 ZDMediator pod 核心逻辑，对 ObjC 调用方零改动，保留 NSProxy 子类、NSInvocation、nil-terminated 变参接口等不可 Swift 化的部分。

**Architecture:** Swift 主导核心逻辑（Mediator 单例、数据类型、Macho section 读取），ObjC 保留 NSProxy 子类、ZDMInvocation、nil-terminated 变参注册/dispatch 接口（作为 ObjC Category 调用 Swift 内部方法）。两侧通过 SPM 混编自动生成的 `ZDMediator-Swift.h` 桥接互操作。

**Tech Stack:** Swift 6.2（SymbolLinkageMarkers 实验特性）、Objective-C、NSRecursiveLock、MachO/dyld API、XCTest

**Spec:** `docs/superpowers/specs/2026-03-24-swift-rewrite-design.md`

---

## File Map

### 新建（Swift）
| 文件 | 职责 |
|------|------|
| `Sources/Classes/Swift/Public/Mediator.swift` | 核心单例，`@objc(ZDMOneForAll)` |
| `Sources/Classes/Swift/Public/MediatorContext.swift` | `@objc(ZDMContext)` |
| `Sources/Classes/Swift/Public/MediatorServiceProtocol.swift` | `@objc(ZDMCommonProtocol)` |
| `Sources/Classes/Swift/Public/MediatorDefine.swift` | Swift 常量、`@_section` 注册辅助 |
| `Sources/Classes/Swift/Private/ServiceRegistration.swift` | 原 ZDMServiceBox |
| `Sources/Classes/Swift/Private/ServiceInstance.swift` | 原 ZDMServiceItem |
| `Sources/Classes/Swift/Private/EventResponder.swift` | 原 ZDMEventResponder |
| `Sources/Classes/Swift/Private/ZDMLock.swift` | NSRecursiveLock 封装 |
| `Sources/Classes/Swift/Tools/SectionReader.swift` | Macho section 读取 |
| `Sources/Classes/Swift/Tools/OrderedSet.swift` | 从 ReerKit 复制 |
| `Sources/Classes/Swift/Tools/NSObject+OnDealloc.swift` | dealloc 回调扩展 |

### 新建（ObjC）
| 文件 | 职责 |
|------|------|
| `Sources/Classes/ObjC/Private/Mediator+Dispatch.h` | dispatch/registerResponder 变参接口声明 |
| `Sources/Classes/ObjC/Private/Mediator+Dispatch.m` | 变参接口实现，调用 Swift 内部方法 |

### 移动（ObjC，保持内容不变）
| 原路径 | 新路径 |
|--------|--------|
| `Sources/Classes/Public/ZDMediator.h` | `Sources/Classes/ObjC/Public/ZDMediator.h` |
| `Sources/Classes/Public/ZDMediatorDefine.h` | `Sources/Classes/ObjC/Public/ZDMediatorDefine.h` |
| `Sources/Classes/Public/ZDMProxy.h/m` | `Sources/Classes/ObjC/Public/ZDMProxy.h/m` |
| `Sources/Classes/Public/ZDMBroadcastProxy.h/m` | `Sources/Classes/ObjC/Public/ZDMBroadcastProxy.h/m` |
| `Sources/Classes/Tools/ZDMInvocation.h/m` | `Sources/Classes/ObjC/Tools/ZDMInvocation.h/m` |
| `Sources/Classes/Tools/ZDMConst.h/m` | `Sources/Classes/ObjC/Tools/ZDMConst.h/m` |

### 修改（ObjC）
| 文件 | 改动内容 |
|------|----------|
| `Sources/Classes/ObjC/Public/ZDMediatorDefine.h` | 替换 `ZDMMachoOFARegisterKV` 为 3 字段 `ZDMMachoKVEntry`，更新宏，`ZDM_DisposeBlock` 改为无参 |
| `Sources/Classes/ObjC/Public/ZDMediator.h` | 移除已删除 ObjC 文件的 `#import`，改为引用 Swift 生成头 |

### 删除（ObjC，功能迁移至 Swift）
`ZDMOneForAll.h/m`、`ZDMOneForAll+Private.h`、`ZDMServiceBox.h/m`、`ZDMServiceItem.h/m`、`ZDMEventResponder.h/m`、`ZDMLock.h/m`、`ZDMContext.h/m`、`ZDMCommonProtocol.h`、`NSObject+ZDMOnDealloc.h/m`

### 修改（配置）
| 文件 | 改动内容 |
|------|----------|
| `Package.swift` | 平台版本、publicHeadersPath、swiftSettings |
| `ZDMediator.podspec` | 版本、source_files glob、pod_target_xcconfig |

---

## Task 1: 创建目录结构，移动 ObjC 文件

**Files:**
- Create: `Sources/Classes/Swift/Public/`, `Private/`, `Tools/`
- Create: `Sources/Classes/ObjC/Public/`, `Private/`, `Tools/`
- Move: 所有原有 ObjC 文件到 `ObjC/` 对应子目录

- [ ] **Step 1: 创建 Swift 和 ObjC 目录结构**

```bash
cd /Users/Zero_D_Saber/Documents/Github/ZDMediator
mkdir -p Sources/Classes/Swift/Public
mkdir -p Sources/Classes/Swift/Private
mkdir -p Sources/Classes/Swift/Tools
mkdir -p Sources/Classes/ObjC/Public
mkdir -p Sources/Classes/ObjC/Private
mkdir -p Sources/Classes/ObjC/Tools
```

- [ ] **Step 2: 移动不变的 ObjC 文件到新位置**

```bash
# Public
mv Sources/Classes/Public/ZDMediator.h Sources/Classes/ObjC/Public/
mv Sources/Classes/Public/ZDMediatorDefine.h Sources/Classes/ObjC/Public/
mv Sources/Classes/Public/ZDMProxy.h Sources/Classes/ObjC/Public/
mv Sources/Classes/Public/ZDMProxy.m Sources/Classes/ObjC/Public/
mv Sources/Classes/Public/ZDMBroadcastProxy.h Sources/Classes/ObjC/Public/
mv Sources/Classes/Public/ZDMBroadcastProxy.m Sources/Classes/ObjC/Public/
# Tools
mv Sources/Classes/Tools/ZDMInvocation.h Sources/Classes/ObjC/Tools/
mv Sources/Classes/Tools/ZDMInvocation.m Sources/Classes/ObjC/Tools/
mv Sources/Classes/Tools/ZDMConst.h Sources/Classes/ObjC/Tools/
mv Sources/Classes/Tools/ZDMConst.m Sources/Classes/ObjC/Tools/
```

- [ ] **Step 3: 验证目录结构**

```bash
find Sources/Classes/ObjC -name "*.h" -o -name "*.m" | sort
```

Expected: 10 个文件（4 Public .h、2 Public .m、2 Tools .h、2 Tools .m）

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "refactor: create Swift/ObjC directory structure, move unchanged ObjC files"
```

---

## Task 2: 更新 Package.swift

**Files:**
- Modify: `Package.swift`

- [ ] **Step 1: 更新 Package.swift**

将 `Package.swift` 替换为：

```swift
// swift-tools-version: 6.0
import PackageDescription

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
            publicHeadersPath: "Classes/ObjC/Public",
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
        .testTarget(
            name: "ZDMediatorTests",
            dependencies: ["ZDMediator"],
            path: "Tests/ZDMediatorTests"
        ),
    ]
)
```

- [ ] **Step 2: 验证 Package.swift 可解析（暂时会失败，因为旧 ObjC 文件已移动但新 Swift 文件尚未创建）**

```bash
cd /Users/Zero_D_Saber/Documents/Github/ZDMediator
swift package dump-package 2>&1 | head -5
```

Expected: 显示 package 信息，无 JSON 错误

- [ ] **Step 3: Commit**

```bash
git add Package.swift
git commit -m "build: update Package.swift for Swift 6, iOS 13+, new directory layout"
```

---

## Task 3: 复制 OrderedSet.swift（来自 ReerKit）

**Files:**
- Create: `Sources/Classes/Swift/Tools/OrderedSet.swift`

- [ ] **Step 1: 从 ReerKit 获取 OrderedSet.swift**

```bash
curl -sL "https://raw.githubusercontent.com/faimin/ReerKit/main/Sources/ReerKit/Utility/DataStructure/OrderedSet.swift" \
  -o Sources/Classes/Swift/Tools/OrderedSet.swift
```

- [ ] **Step 2: 确认文件非空**

```bash
wc -l Sources/Classes/Swift/Tools/OrderedSet.swift
```

Expected: > 50 行

- [ ] **Step 3: 检查访问控制级别，确认 `OrderedSet` 类型可用于模块内部**

```bash
head -30 Sources/Classes/Swift/Tools/OrderedSet.swift
```

如果是 `public struct OrderedSet`，在 `Mediator.swift` 内部使用时 OK。如果带有 module 前缀，调整 import 即可。

- [ ] **Step 4: Commit**

```bash
git add Sources/Classes/Swift/Tools/OrderedSet.swift
git commit -m "feat: add OrderedSet from ReerKit (single file copy)"
```

---

## Task 4: ZDMLock.swift

**Files:**
- Create: `Sources/Classes/Swift/Private/ZDMLock.swift`

- [ ] **Step 1: 创建 ZDMLock.swift**

```swift
// Sources/Classes/Swift/Private/ZDMLock.swift

final class ZDMLock: @unchecked Sendable {
    private let _lock = NSRecursiveLock()

    func lock()   { _lock.lock() }
    func unlock() { _lock.unlock() }

    @discardableResult
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        _lock.lock()
        defer { _lock.unlock() }
        return try body()
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Sources/Classes/Swift/Private/ZDMLock.swift
git commit -m "feat: add ZDMLock Swift wrapper for NSRecursiveLock"
```

---

## Task 5: 核心数据类型（Context、Registration、Instance、EventResponder）

**Files:**
- Create: `Sources/Classes/Swift/Public/MediatorContext.swift`
- Create: `Sources/Classes/Swift/Private/ServiceRegistration.swift`
- Create: `Sources/Classes/Swift/Private/ServiceInstance.swift`
- Create: `Sources/Classes/Swift/Private/EventResponder.swift`

- [ ] **Step 1: 创建 MediatorContext.swift**

```swift
// Sources/Classes/Swift/Public/MediatorContext.swift
import Foundation

@objc(ZDMContext)
public final class MediatorContext: NSObject {
    @objc public var launchOptions: [AnyHashable: Any]?
    @objc public var extraObj: AnyObject?
}
```

- [ ] **Step 2: 创建 ServiceRegistration.swift**

```swift
// Sources/Classes/Swift/Private/ServiceRegistration.swift
import Foundation

final class ServiceRegistration {
    unowned(unsafe) var cls: AnyClass
    let protocolName: String
    var autoInit: Bool
    var isAllClassMethods: Bool
    var priority: Int

    init(cls: AnyClass, protocolName: String, autoInit: Bool = true,
         isAllClassMethods: Bool = false, priority: Int = 0) {
        self.cls = cls
        self.protocolName = protocolName
        self.autoInit = autoInit
        self.isAllClassMethods = isAllClassMethods
        self.priority = priority
    }
}
```

- [ ] **Step 3: 创建 ServiceInstance.swift**

```swift
// Sources/Classes/Swift/Private/ServiceInstance.swift
import Foundation

final class ServiceInstance {
    private var _strong: AnyObject?
    private weak var _weak: AnyObject?

    var obj: AnyObject? { _strong ?? _weak }

    func store(_ newObj: AnyObject, weak isWeak: Bool) {
        // 替换前通知旧实例
        notifyWillDispose()
        if isWeak {
            _strong = nil
            _weak = newObj
        } else {
            _strong = newObj
            _weak = nil
        }
    }

    func clear() {
        notifyWillDispose()
        _strong = nil
        _weak = nil
    }

    private func notifyWillDispose() {
        let old = _strong ?? _weak
        if let disposable = old as? AnyObject,
           disposable.responds(to: NSSelectorFromString("zdm_willDispose")) {
            _ = disposable.perform(NSSelectorFromString("zdm_willDispose"))
        }
    }

    static func withStrong(_ obj: AnyObject) -> ServiceInstance {
        let item = ServiceInstance()
        item._strong = obj
        return item
    }

    static func withWeak(_ obj: AnyObject) -> ServiceInstance {
        let item = ServiceInstance()
        item._weak = obj
        return item
    }
}
```

> **注意：** `ServiceInstance.notifyWillDispose` 使用 `performs(selector:)` 而非直接协议调用，以避免在此 internal 文件中引入 `MediatorServiceProtocol` 依赖（循环引用风险）。编译后二者等效。

- [ ] **Step 4: 创建 EventResponder.swift**

```swift
// Sources/Classes/Swift/Private/EventResponder.swift
import Foundation

struct EventResponder: Hashable {
    let serviceName: String
    let priority: Int

    // 等值判断只看 serviceName（与原 OC isEqual: 行为一致）
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.serviceName == rhs.serviceName
    }

    // hash 只结合参与 == 的字段，满足 Hashable 契约
    func hash(into hasher: inout Hasher) {
        hasher.combine(serviceName)
    }
}
```

- [ ] **Step 5: Commit**

```bash
git add Sources/Classes/Swift/Public/MediatorContext.swift \
        Sources/Classes/Swift/Private/ServiceRegistration.swift \
        Sources/Classes/Swift/Private/ServiceInstance.swift \
        Sources/Classes/Swift/Private/EventResponder.swift
git commit -m "feat: add core Swift data types (Context, Registration, Instance, EventResponder)"
```

---

## Task 6: MediatorServiceProtocol.swift

**Files:**
- Create: `Sources/Classes/Swift/Public/MediatorServiceProtocol.swift`

- [ ] **Step 1: 创建 MediatorServiceProtocol.swift**

```swift
// Sources/Classes/Swift/Public/MediatorServiceProtocol.swift
import Foundation

// ZDMCommonCallback 定义在 ZDMediatorDefine.h，通过 Swift 模块自动桥接
// 此处无需重复声明

@objc(ZDMCommonProtocol)
public protocol MediatorServiceProtocol: NSObjectProtocol {
    /// 优先级（用于多实现排序）
    @objc optional static func zdm_priority() -> Int

    /// 自定义初始化工厂方法
    /// 注：返回 AnyObject? 而非 Self，兼容 @objc（Self 在 @objc 中不可表示）
    @objc optional static func zdm_createInstance(_ context: MediatorContext?) -> AnyObject

    /// alloc init 之后调用
    @objc optional func zdm_setup()

    /// 即将被释放前调用
    @objc optional func zdm_willDispose()

    /// 模块间通用事件处理
    @objc(zdm_handleEvent:userInfo:callback:)
    optional func zdm_handleEvent(
        _ event: Int,
        userInfo: Any?,
        callback: ZDMCommonCallback?
    ) -> Bool
}
```

- [ ] **Step 2: Commit**

```bash
git add Sources/Classes/Swift/Public/MediatorServiceProtocol.swift
git commit -m "feat: add MediatorServiceProtocol (ObjC: ZDMCommonProtocol)"
```

---

## Task 7: 更新 ZDMediatorDefine.h（新 3 字段 struct + 更新宏）

**Files:**
- Modify: `Sources/Classes/ObjC/Public/ZDMediatorDefine.h`

- [ ] **Step 1: 替换 ZDMediatorDefine.h 内容**

将原有文件替换为：

```objc
//  ZDMediatorDefine.h
//  ZDMediator 0.5.0 - Breaking Change: ZDMMachoKVEntry 从 5 字段简化为 3 字段

#ifndef ZDMediatorDefine_h
#define ZDMediatorDefine_h

#import <Foundation/Foundation.h>
#import <mach-o/loader.h>

#ifndef ZDMDefaultPriority
#define ZDMDefaultPriority ((NSInteger)0)
#endif

#if DEBUG
#ifndef ZDMLog
#define ZDMLog(...) NSLog(@"❌❌❌" __VA_ARGS__);
#endif
#else
#ifndef ZDMLog
#define ZDMLog(...)
#endif
#endif

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wstrict-prototypes"
// Breaking Change (0.5.0): 简化为无参 block，与 Swift 版本保持一致
typedef id (^ZDMCommonCallback)(void);
#pragma clang diagnostic pop

//-------------------------Macho Section------------------------------

/// Macho section 数据格式（0.5.0 Breaking Change：从 5 字段简化为 3 字段）
/// priority 从 zdm_priority() 获取，isAllClassMethods 运行时检测
typedef struct {
    const char * _Nonnull protocol_name;  // 8 bytes
    const char * _Nonnull class_name;     // 8 bytes
    int32_t      auto_init;               // 4 bytes（1=autoInit, 0=manualInit）
    int32_t      _padding;                // 4 bytes（显式对齐，total=24 bytes）
} ZDMMachoKVEntry;

#ifndef ZDMediatorOFASectionName
#define ZDMediatorOFASectionName "__ZDMKV_OFA"
#endif

/// 自动注册宏（autoInit=YES，首次 service() 调用时自动创建实例）
#ifndef ZDMediatorOFARegister
#define ZDMediatorOFARegister(protocol_name, cls)                               \
    __attribute__((no_sanitize_address))                                         \
    __attribute__((used, section(SEG_DATA "," ZDMediatorOFASectionName)))        \
    static const ZDMMachoKVEntry ZDMKV_OFA_##protocol_name##_##cls = {          \
        .protocol_name = (NO && ((void)@protocol(protocol_name), NO), #protocol_name), \
        .class_name    = (NO && ((void)[cls class], NO), #cls),                 \
        .auto_init     = 1,                                                      \
        ._padding      = 0,                                                      \
    };
#endif

/// 手动注册宏（autoInit=NO，需手动调用 manualRegisterService:）
#ifndef ZDMediatorOFARegisterManual
#define ZDMediatorOFARegisterManual(protocol_name, cls)                          \
    __attribute__((no_sanitize_address))                                         \
    __attribute__((used, section(SEG_DATA "," ZDMediatorOFASectionName)))        \
    static const ZDMMachoKVEntry ZDMKV_OFA_Manual_##protocol_name##_##cls = {   \
        .protocol_name = (NO && ((void)@protocol(protocol_name), NO), #protocol_name), \
        .class_name    = (NO && ((void)[cls class], NO), #cls),                 \
        .auto_init     = 0,                                                      \
        ._padding      = 0,                                                      \
    };
#endif

/// 1:1 注册宏（等同于 ZDMediatorOFARegister，priority 由 +zdm_priority 决定）
#ifndef ZDMediator1V1Register
#define ZDMediator1V1Register(protocol_name, cls) \
    ZDMediatorOFARegister(protocol_name, cls)
#endif

//-------------------Service Getter Macros-------------------

/// 获取 protocol 对应的服务实例（priority=0，默认最高优先级回退）
#ifndef ZDMGetService
#define ZDMGetService(protocol_name) \
    ((id<protocol_name>)[[ZDMOneForAll class] service:@protocol(protocol_name) priority:0])
#endif

/// 获取指定 priority 的服务实例
#ifndef ZDMGetServiceWithPriority
#define ZDMGetServiceWithPriority(protocol_name, priority) \
    ((id<protocol_name>)[[ZDMOneForAll class] service:@protocol(protocol_name) priority:(priority)])
#endif

/// 只从缓存获取，不触发自动初始化
#ifndef ZDMGetServiceFromCache
#define ZDMGetServiceFromCache(protocol_name) \
    ((id<protocol_name>)[[ZDMOneForAll class] serviceWithName:NSStringFromProtocol(@protocol(protocol_name)) \
                                                      priority:0 \
                                                 onlyFromCache:YES])
#endif

/// 通过 class 直接获取（绕过协议查找，返回已注册的类方法实例）
#ifndef ZDMGetServiceWithClass
#define ZDMGetServiceWithClass(cls_name) \
    ([[ZDMOneForAll class] serviceWithName:NSStringFromClass([cls_name class]) priority:0])
#endif

#endif /* ZDMediatorDefine_h */
```

- [ ] **Step 2: Commit**

```bash
git add Sources/Classes/ObjC/Public/ZDMediatorDefine.h
git commit -m "feat!: update ZDMediatorDefine.h - 3-field ZDMMachoKVEntry, no-arg ZDMCommonCallback (BREAKING)"
```

---

## Task 8: SectionReader.swift

**Files:**
- Create: `Sources/Classes/Swift/Tools/SectionReader.swift`

- [ ] **Step 1: 创建 SectionReader.swift**

```swift
// Sources/Classes/Swift/Tools/SectionReader.swift
import MachO
import Foundation

/// Macho section 数据结构，与 C 端的 ZDMMachoKVEntry 内存布局完全一致
/// @frozen 保证跨编译器版本 layout 稳定
@frozen
struct SectionEntry {
    let protocolNamePtr: UnsafePointer<CChar>
    let classNamePtr: UnsafePointer<CChar>
    let autoInit: Int32
    let _padding: Int32
}

// 编译期断言：确保 Swift struct 与 C struct ZDMMachoKVEntry 内存布局一致
// size=24, stride=24 (2×8 + 2×4, aligned to 8), alignment=8
private let _layoutCheck: () = {
    assert(MemoryLayout<SectionEntry>.size == 24,
           "SectionEntry size mismatch: expected 24, got \(MemoryLayout<SectionEntry>.size)")
    assert(MemoryLayout<SectionEntry>.stride == 24,
           "SectionEntry stride mismatch")
    assert(MemoryLayout<SectionEntry>.alignment == 8,
           "SectionEntry alignment mismatch")
}()

enum SectionReader {
    /// 从所有已加载 dyld 镜像的 __DATA,__ZDMKV_OFA section 读取注册数据
    /// 只处理 64-bit 镜像（最低部署目标已排除所有 32-bit 设备）
    static func readKVEntries() -> [(protocolName: String, className: String, autoInit: Bool)] {
        _ = _layoutCheck  // 触发断言
        var results: [(String, String, Bool)] = []
        let imageCount = _dyld_image_count()
        for i in 0..<imageCount {
            guard let header = _dyld_get_image_header(i) else { continue }
            guard header.pointee.magic == MH_MAGIC_64 else { continue }
            var size: UInt = 0
            guard let ptr = getsectiondata(
                UnsafeRawPointer(header).assumingMemoryBound(to: mach_header_64.self),
                "__DATA",
                "__ZDMKV_OFA",
                &size
            ) else { continue }
            let count = Int(size) / MemoryLayout<SectionEntry>.stride
            guard count > 0 else { continue }
            let buffer = UnsafeBufferPointer(
                start: ptr.assumingMemoryBound(to: SectionEntry.self),
                count: count
            )
            for entry in buffer {
                let proto = String(cString: entry.protocolNamePtr)
                let cls   = String(cString: entry.classNamePtr)
                guard !proto.isEmpty, !cls.isEmpty else { continue }
                results.append((proto, cls, entry.autoInit != 0))
            }
        }
        return results
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Sources/Classes/Swift/Tools/SectionReader.swift
git commit -m "feat: add SectionReader for Macho __ZDMKV_OFA section with layout assertions"
```

---

## Task 9: NSObject+OnDealloc.swift

**Files:**
- Create: `Sources/Classes/Swift/Tools/NSObject+OnDealloc.swift`

- [ ] **Step 1: 创建 NSObject+OnDealloc.swift**

```swift
// Sources/Classes/Swift/Tools/NSObject+OnDealloc.swift
import Foundation
import ObjectiveC

private final class DeallocExecutor: NSObject {
    let block: () -> Void
    init(_ block: @escaping () -> Void) { self.block = block }
    deinit { block() }
}

private var deallocKey: UInt8 = 0

extension NSObject {
    /// 注册一个 block，在 self 被释放时执行
    /// Breaking Change (0.5.0): block 从 `(id) -> Void` 简化为 `() -> Void`
    /// 所有内部调用点需从 `^(id realTarget){...}` 改为 `^{...}`
    @objc public func zdm_onDealloc(_ block: @escaping () -> Void) {
        var executors = objc_getAssociatedObject(self, &deallocKey) as? [DeallocExecutor] ?? []
        executors.append(DeallocExecutor(block))
        objc_setAssociatedObject(self, &deallocKey, executors, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Sources/Classes/Swift/Tools/NSObject+OnDealloc.swift
git commit -m "feat: add NSObject+OnDealloc.swift (dealloc callback extension)"
```

---

## Task 10: MediatorDefine.swift（Swift 侧公共定义）

**Files:**
- Create: `Sources/Classes/Swift/Public/MediatorDefine.swift`

- [ ] **Step 1: 创建 MediatorDefine.swift**

```swift
// Sources/Classes/Swift/Public/MediatorDefine.swift
import Foundation

// MARK: - 内部工具函数

/// 生成 registerInfoDict 的 key："protocolName--->priority"
let zdmJoinKey = "--->"

func zdmStoreKey(_ serviceName: String, _ priority: Int) -> String {
    "\(serviceName)\(zdmJoinKey)\(priority)"
}

// MARK: - Swift 调用辅助

/// 类型安全的服务获取（Swift 侧使用）
/// 等同于 ObjC 的 ZDMGetService(proto)
public func zdmService<T>(_ type: T.Type, priority: Int = 0) -> T? {
    let name = String(reflecting: type)
    // 先尝试用协议名查找，如果找不到，走 ObjC 桥接路径
    // 注：Swift protocol 的 NSStringFromProtocol 等价是 String(reflecting:)
    return Mediator.serviceWithName(name, priority: priority) as? T
}

// MARK: - Swift 侧 @_section 注册辅助
// 使用方（Swift 模块内）：
//
//   @_used @_section("__DATA,__ZDMKV_OFA")
//   private let _myEntry = zdmMakeSectionEntry("MyProtocol", "MyClass", autoInit: true)
//
// 注：StaticString.utf8Start 对所有 ASCII 字符串（协议名/类名）始终是指针形式，安全。

/// 创建 section entry（供 Swift 模块内 @_section 注册使用）
public func zdmMakeSectionEntry(
    _ protocolName: StaticString,
    _ className: StaticString,
    autoInit: Bool = true
) -> SectionEntry {
    precondition(protocolName.hasPointerRepresentation,
                 "protocolName must be a pointer-representation StaticString (ASCII literal)")
    precondition(className.hasPointerRepresentation,
                 "className must be a pointer-representation StaticString (ASCII literal)")
    return SectionEntry(
        protocolNamePtr: protocolName.utf8Start
            .withMemoryRebound(to: CChar.self, capacity: protocolName.utf8CodeUnitCount) { $0 },
        classNamePtr: className.utf8Start
            .withMemoryRebound(to: CChar.self, capacity: className.utf8CodeUnitCount) { $0 },
        autoInit: autoInit ? 1 : 0,
        _padding: 0
    )
}
```

- [ ] **Step 2: Commit**

```bash
git add Sources/Classes/Swift/Public/MediatorDefine.swift
git commit -m "feat: add MediatorDefine.swift (store key helper, Swift service accessor, section entry factory)"
```

---

## Task 11: Mediator.swift Part 1 — 状态声明、单例、Section 加载、注册

**Files:**
- Create: `Sources/Classes/Swift/Public/Mediator.swift`

- [ ] **Step 1: 创建 Mediator.swift — 类声明与状态**

```swift
// Sources/Classes/Swift/Public/Mediator.swift
import Foundation
import ObjectiveC

@objc(ZDMOneForAll)
public final class Mediator: NSObject, @unchecked Sendable {

    // MARK: - Singleton

    @objc public static let shared = Mediator()
    private override init() { super.init() }

    // 原 shareInstance（兼容旧调用）
    @objc public static func shareInstance() -> Mediator { shared }

    // MARK: - Internal State（全部由 lock 保护）

    /// "protocolName--->priority" → ServiceRegistration
    var registerInfoDict: [String: ServiceRegistration] = [:]
    /// className → Set<"protocolName--->priority">（O(1) contains）
    var registerClassDict: [String: Set<String>] = [:]
    /// protocolName → [Int]（降序排列，首元素为最高优先级）
    var priorityDict: [String: [Int]] = [:]
    /// className → ServiceInstance
    var instanceDict: [String: ServiceInstance] = [:]
    /// eventId/selectorName → OrderedSet<EventResponder>（按 priority 降序）
    var eventResponderDict: [String: OrderedSet<EventResponder>] = [:]

    let lock = ZDMLock()
    private var _sectionLoaded = false
    private var _proxyInitialized = false

    // ZDMBroadcastProxy 实例（NSProxy 子类，用 alloc 不用 init）
    // ZDMBroadcastProxy.h 在 publicHeadersPath 内，Swift 可直接引用
    @objc public private(set) lazy var proxy: AnyObject = ZDMBroadcastProxy.alloc()

    @objc public var context: MediatorContext?
}

- [ ] **Step 2: 添加 Section 懒加载方法**

在 `Mediator.swift` 中追加：

```swift
// MARK: - Section 懒加载

extension Mediator {
    /// 首次服务访问时调用，只执行一次，持锁期间扫描所有 dyld 镜像（一次性开销）
    func loadSectionIfNeeded() {
        lock.withLock {
            guard !_sectionLoaded else { return }
            _sectionLoaded = true
            let entries = SectionReader.readKVEntries()
            for e in entries {
                _registerFromSection(protocolName: e.protocolName,
                                     className: e.className,
                                     autoInit: e.autoInit)
            }
        }
    }

    private func _registerFromSection(protocolName: String, className: String, autoInit: Bool) {
        guard let cls = objc_getClass(className) as? AnyClass else {
            zdmLog("class not found: \(className)")
            return
        }
        // priority 从类的 zdm_priority() 获取，否则默认 0
        // 注：zdm_priority() 返回 NSInteger（标量），不能用 perform 取返回值（UB）
        // 必须通过协议类型调用
        let priority = (cls as? MediatorServiceProtocol.Type)?.zdm_priority?() ?? 0

        let registration = ServiceRegistration(
            cls: cls,
            protocolName: protocolName,
            autoInit: autoInit,
            isAllClassMethods: false,  // Macho 注册默认为 false，运行时按需修正
            priority: priority
        )
        _store(registration: registration, forServiceName: protocolName)
    }
}

private func zdmLog(_ message: String) {
#if DEBUG
    print("❌❌❌ ZDMediator: \(message)")
#endif
}
```

- [ ] **Step 3: 添加注册方法**

在 `Mediator.swift` 中追加：

```swift
// MARK: - 注册（对外 API）

extension Mediator {

    // MARK: ObjC API

    @objc public static func registerService(
        _ serviceProtocol: Protocol,
        priority: Int,
        implementClass cls: AnyClass
    ) {
        let serviceName = NSStringFromProtocol(serviceProtocol)
        let registration = ServiceRegistration(
            cls: cls, protocolName: serviceName,
            autoInit: true, isAllClassMethods: false, priority: priority
        )
        shared._store(registration: registration, forServiceName: serviceName)
    }

    @objc public static func manualRegisterService(
        _ serviceProtocol: Protocol,
        implementer obj: AnyObject
    ) {
        manualRegisterService(serviceProtocol, priority: 0, implementer: obj, weakStore: false)
    }

    @objc public static func manualRegisterService(
        _ serviceProtocol: Protocol,
        priority: Int,
        implementer obj: AnyObject,
        weakStore: Bool
    ) {
        guard let cls = object_getClass(obj) else { return }
        let serviceName = NSStringFromProtocol(serviceProtocol)
        let clsName = NSStringFromClass(cls)

        // 检查是否已通过 Macho 注册
        let key = zdmStoreKey(serviceName, priority)
        let alreadyRegistered = shared.lock.withLock {
            shared.registerClassDict[clsName]?.contains(key) ?? false
        }

        if !alreadyRegistered {
            let registration = ServiceRegistration(
                cls: cls,
                protocolName: serviceName,
                autoInit: false,
                isAllClassMethods: object_isClass(obj),  // 传入 Class 对象则认为全类方法
                priority: priority
            )
            shared._store(registration: registration, forServiceName: serviceName)
        }

        // 存储实例
        shared._storeInstance(obj, weak: weakStore)

        // 弱引用时注册 dealloc 回调，自动清理
        // Protocol * 是全局单例指针，不是堆对象，不能 [weak] 捕获，直接值捕获安全
        if weakStore && !object_isClass(obj), let nsObj = obj as? NSObject {
            nsObj.zdm_onDealloc {
                Mediator.removeService(serviceProtocol, priority: priority, autoInitAgain: false)
            }
        }
    }

    // MARK: 内部通用存储

    func _store(registration: ServiceRegistration, forServiceName serviceName: String) {
        let priority = registration.priority
        let key = zdmStoreKey(serviceName, priority)
        let clsName = NSStringFromClass(registration.cls)

        lock.withLock {
            // 更新 priorityDict（降序）
            var priorities = priorityDict[serviceName] ?? []
#if DEBUG
            if priorities.contains(priority) {
                let existing = registerInfoDict[key]?.cls
                if NSStringFromClass(existing!) != NSStringFromClass(registration.cls) {
                    assertionFailure("❌ 同一 Protocol(\(serviceName)) 下有多个类注册了相同 Priority(\(priority))")
                }
            }
#endif
            if !priorities.contains(priority) {
                priorities.append(priority)
                priorities.sort(by: >) // 降序
                priorityDict[serviceName] = priorities
            }

            registerInfoDict[key] = registration

            // 更新 registerClassDict
            var keySet = registerClassDict[clsName] ?? Set()
            keySet.insert(key)
            registerClassDict[clsName] = keySet

            // 全类方法：预存 class 本身到 instanceDict（与注册更新原子化，避免竞争）
            if registration.isAllClassMethods {
                instanceDict[clsName] = ServiceInstance.withStrong(registration.cls)
            }
        }

        _updateProxyTargets()
    }

    func _storeInstance(_ obj: AnyObject, weak isWeak: Bool) {
        guard let cls = object_getClass(obj) else { return }
        let clsName = NSStringFromClass(cls)
        let item: ServiceInstance = isWeak ? .withWeak(obj) : .withStrong(obj)
        lock.withLock {
            instanceDict[clsName] = item
        }
    }
}
```

- [ ] **Step 4: Commit**

```bash
git add Sources/Classes/Swift/Public/Mediator.swift
git commit -m "feat: add Mediator.swift Part 1 - state, singleton, section loading, registration"
```

---

## Task 12: Mediator.swift Part 2 — 服务获取、实例创建、移除、调试接口

**Files:**
- Modify: `Sources/Classes/Swift/Public/Mediator.swift`

- [ ] **Step 1: 追加服务获取方法**

在 `Mediator.swift` 末尾追加：

```swift
// MARK: - 服务获取（对外 API）

extension Mediator {

    @objc public static func service(_ serviceProtocol: Protocol, priority: Int) -> AnyObject? {
        let name = NSStringFromProtocol(serviceProtocol)
        return _service(name: name, priority: priority, needProxyWrap: true, onlyFromCache: false)
    }

    @objc public static func serviceWithName(_ name: String, priority: Int) -> AnyObject? {
        _service(name: name, priority: priority, needProxyWrap: true, onlyFromCache: false)
    }

    @objc public static func serviceWithName(
        _ name: String,
        priority: Int,
        onlyFromCache: Bool
    ) -> AnyObject? {
        _service(name: name, priority: priority, needProxyWrap: true, onlyFromCache: onlyFromCache)
    }

    // MARK: 内部核心获取方法

    static func _service(
        name: String,
        priority: Int,
        needProxyWrap: Bool,
        onlyFromCache: Bool = false
    ) -> AnyObject? {
        shared.loadSectionIfNeeded()

        let effectivePriority = shared.lock.withLock { () -> Int in
            let priorities = shared.priorityDict[name] ?? []
            // Fault tolerance: priority=0 找不到时 fallback 到最高 priority
            if priority == 0 && !priorities.contains(0) && !priorities.isEmpty {
                return priorities[0] // 降序第一个即最高
            }
            return priority
        }

        let key = zdmStoreKey(name, effectivePriority)
        guard let registration = shared.lock.withLock({ shared.registerInfoDict[key] }) else {
            zdmLog("请先注册 protocol: \(name)")
            return nil
        }

        let clsName = NSStringFromClass(registration.cls)
        var instance = shared.lock.withLock { shared.instanceDict[clsName]?.obj }

        if (instance == nil || object_isClass(instance)) && registration.autoInit && !onlyFromCache {
            instance = shared._createInstance(registration)
        }

        guard let instance else { return nil }

        // ZDMProxy 包装（防止不识别方法时崩溃）
        if needProxyWrap,
           let proxyClass = NSClassFromString("ZDMProxy") as? NSObject.Type {
            // 等效于 [ZDMProxy proxyWithTarget:instance]
            // 通过 ObjC 消息转发调用
            let proxy = proxyClass.perform(
                NSSelectorFromString("proxyWithTarget:"),
                with: instance
            )?.takeUnretainedValue()

            // 设置 fixme 回调：当发现协议并非全类方法时，自动修正并创建实例
            if let proxy = proxy as? AnyObject,
               proxy.responds(to: NSSelectorFromString("fixmeWithCallback:")) {
                let fixme: @convention(block) () -> AnyObject? = { [weak registration] in
                    guard let reg = registration else { return nil }
                    reg.isAllClassMethods = false
                    return shared._createInstance(reg)
                }
                proxy.perform(
                    NSSelectorFromString("fixmeWithCallback:"),
                    with: fixme as AnyObject
                )
            }
            return proxy as AnyObject?
        }

        return instance
    }

    // MARK: 实例创建

    func _createInstance(_ registration: ServiceRegistration) -> AnyObject? {
        let cls = registration.cls
        let clsName = NSStringFromClass(cls)

        // 1. 已有实例直接返回
        if let existing = lock.withLock({ instanceDict[clsName]?.obj }),
           !object_isClass(existing) {
            return existing
        }

        var instance: AnyObject?

        // 2. 全类方法：返回 class 本身
        if registration.isAllClassMethods {
            instance = cls
        }
        // 3. 自定义工厂
        else if cls.responds(to: NSSelectorFromString("zdm_createInstance:")) {
            let ctx = context
            instance = cls.perform(NSSelectorFromString("zdm_createInstance:"), with: ctx)?
                .takeUnretainedValue() as AnyObject?
        }
        // 4. 默认 alloc（先存再 init，防循环依赖）
        // 注：AnyClass 在 Swift 中没有 .alloc()，必须通过 ObjC 消息转发
        // init 返回 id（对象），takeUnretainedValue() 是安全的
        else {
            guard let allocated = (cls as AnyObject)
                .perform(NSSelectorFromString("alloc"))?.takeUnretainedValue() else { return nil }
            lock.withLock { instanceDict[clsName] = ServiceInstance.withStrong(allocated) }
            instance = (allocated as AnyObject)
                .perform(NSSelectorFromString("init"))?.takeUnretainedValue() ?? allocated
        }

        guard let instance else { return nil }

        // 存储
        lock.withLock { instanceDict[clsName] = ServiceInstance.withStrong(instance) }

        // 5. 调用 zdm_setup
        if instance.responds(to: NSSelectorFromString("zdm_setup")) {
            _ = instance.perform(NSSelectorFromString("zdm_setup"))
        }

        return instance
    }
}
```

- [ ] **Step 2: 追加 removeService、allInitializedObjects、allRegisterClasses**

在 `Mediator.swift` 末尾追加：

```swift
// MARK: - 移除服务

extension Mediator {

    @objc @discardableResult
    public static func removeService(
        _ serviceProtocol: Protocol,
        priority: Int,
        autoInitAgain: Bool
    ) -> Bool {
        let serviceName = NSStringFromProtocol(serviceProtocol)
        let key = zdmStoreKey(serviceName, priority)
        let mediator = shared

        var item: ServiceInstance?
        var shouldUpdateProxy = false

        mediator.lock.withLock {
            // 更新 priorityDict
            // 只在 !autoInitAgain 时从 priorityDict 移除；
            // autoInitAgain=true 时只清除实例，保留注册信息（与 ObjC 行为一致）
            if !autoInitAgain {
                mediator.priorityDict[serviceName]?.removeAll { $0 == priority }
                if mediator.priorityDict[serviceName]?.isEmpty == true {
                    mediator.priorityDict[serviceName] = nil
                }
            }

            guard let registration = mediator.registerInfoDict[key] else { return }
            registration.autoInit = autoInitAgain

            let clsName = NSStringFromClass(registration.cls)
            item = mediator.instanceDict[clsName]
            mediator.instanceDict[clsName] = nil

            mediator.registerClassDict[clsName]?.remove(key)
            if !autoInitAgain {
                if mediator.registerClassDict[clsName]?.isEmpty == true {
                    mediator.registerClassDict[clsName] = nil
                }
                mediator.registerInfoDict[key] = nil
                shouldUpdateProxy = true
            }
        }

        if shouldUpdateProxy { _updateProxyTargets() }
        item?.clear()
        return item != nil
    }
}

// MARK: - 调试接口

extension Mediator {

    @objc public static func allInitializedObjects() -> NSHashTable<AnyObject> {
        shared.loadSectionIfNeeded()
        let table = NSHashTable<AnyObject>.weakObjects()
        shared.lock.withLock {
            for item in shared.instanceDict.values {
                if let obj = item.obj { table.add(obj) }
            }
        }
        return table
    }

    @objc public static func allRegisterClasses() -> NSOrderedSet {
        shared.loadSectionIfNeeded()
        let boxes = shared.lock.withLock { Array(shared.registerInfoDict.values) }
        let sorted = boxes.sorted { $0.priority >= $1.priority }
        let orderedSet = NSMutableOrderedSet()
        for reg in sorted { orderedSet.add(reg.cls) }
        return orderedSet.copy() as! NSOrderedSet
    }

    static func _updateProxyTargets() {
        let clsSet = allRegisterClasses()
        // 调用 ZDMBroadcastProxy.replaceTargetSet:
        _ = shared.proxy?.perform(
            NSSelectorFromString("replaceTargetSet:"),
            with: clsSet
        )
    }

    // proxy 访问时懒初始化 targets（与原 OC 行为一致）
    // 使用 ZDMLock 保证线程安全，避免 struct Once { static var done } 的非原子性问题
    @objc public var proxyForBroadcast: AnyObject? {
        lock.withLock {
            if !_proxyInitialized {
                _proxyInitialized = true
                _ = proxy.perform(
                    NSSelectorFromString("replaceTargetSet:"),
                    with: Mediator.allRegisterClasses()
                )
            }
        }
        return proxy
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add Sources/Classes/Swift/Public/Mediator.swift
git commit -m "feat: add Mediator.swift Part 2 - service lookup, instance creation, remove, debug APIs"
```

---

## Task 13: Mediator.swift Part 3 — 事件系统（内部注册 + dispatch 查询接口）

**Files:**
- Modify: `Sources/Classes/Swift/Public/Mediator.swift`

- [ ] **Step 1: 追加事件注册内部方法（供 ObjC Category 调用）**

在 `Mediator.swift` 末尾追加：

```swift
// MARK: - 事件注册（ObjC Category 调用的内部接口）

extension Mediator {

    /// 注册 eventId 响应者（由 Mediator+Dispatch.m 的变参方法调用）
    @objc(_registerResponderForProtocol:priority:eventIds:)
    public func _registerResponder(
        forProtocol serviceProtocol: Protocol,
        priority: Int,
        eventIds: [String]
    ) {
        for eventId in eventIds {
            _registerResponder(protocol: serviceProtocol, priority: priority, eventKey: eventId)
        }
    }

    /// 注册 SEL 响应者（由 Mediator+Dispatch.m 的变参方法调用）
    @objc(_registerResponderForProtocol:priority:selectorNames:)
    public func _registerResponder(
        forProtocol serviceProtocol: Protocol,
        priority: Int,
        selectorNames: [String]
    ) {
        for name in selectorNames {
            _registerResponder(protocol: serviceProtocol, priority: priority, eventKey: name)
        }
    }

    private func _registerResponder(protocol: Protocol, priority: Int, eventKey: String) {
        guard !eventKey.isEmpty else { return }
        let serviceName = NSStringFromProtocol(`protocol`)
        let responder = EventResponder(serviceName: serviceName, priority: priority)

        lock.withLock {
            var set = eventResponderDict[eventKey] ?? OrderedSet()
            // 去重：同 serviceName 先移后插（更新 priority）
            set.remove(responder)
            // 按 priority 降序插入
            if let idx = set.firstIndex(where: { $0.priority <= priority }) {
                set.insert(responder, at: idx)
            } else {
                set.append(responder)
            }
            eventResponderDict[eventKey] = set
        }
    }
}

// MARK: - Dispatch 查询接口（ObjC Category 调用，Option B 架构）

extension Mediator {

    /// 获取某 Protocol 的有序服务实例列表（按 priority 降序）
    @objc(_serviceInstancesForProtocol:)
    public func _serviceInstances(forProtocol proto: Protocol) -> [AnyObject] {
        loadSectionIfNeeded()
        let serviceName = NSStringFromProtocol(proto)
        let priorities = lock.withLock { priorityDict[serviceName] ?? [] }
        return priorities.compactMap { priority in
            Mediator._service(name: serviceName, priority: priority,
                              needProxyWrap: false, onlyFromCache: false)
        }
    }

    /// 获取某 eventId 对应的有序服务实例列表
    @objc(_serviceInstancesForEventId:)
    public func _serviceInstances(forEventId eventId: String) -> [AnyObject] {
        loadSectionIfNeeded()
        let responders = lock.withLock { Array(eventResponderDict[eventId] ?? OrderedSet()) }
        var results: [AnyObject] = []
        for responder in responders {
            let priorities = lock.withLock { priorityDict[responder.serviceName] ?? [] }
            for priority in priorities {
                if let inst = Mediator._service(name: responder.serviceName, priority: priority,
                                                needProxyWrap: false) {
                    results.append(inst)
                }
            }
        }
        return results
    }

    /// 获取某 SEL 名（作为 eventId）对应的有序服务实例列表
    @objc(_serviceInstancesForSelectorName:)
    public func _serviceInstances(forSelectorName selName: String) -> [AnyObject] {
        _serviceInstances(forEventId: selName)
    }

    /// 获取所有已注册且响应某 SEL 的服务实例（用于 dispatchWithSELAndArgs:）
    @objc(_allServiceInstancesRespondingToSelectorName:)
    public func _allServiceInstances(respondingToSelectorName selName: String) -> [AnyObject] {
        loadSectionIfNeeded()
        let sel = NSSelectorFromString(selName)
        let clsNames = lock.withLock { Array(registerClassDict.keys) }
        var results: [AnyObject] = []

        for clsName in clsNames {
            let (box, existingInst) = lock.withLock { () -> (ServiceRegistration?, AnyObject?) in
                guard let key = registerClassDict[clsName]?.first,
                      let reg = registerInfoDict[key] else { return (nil, nil) }
                return (reg, instanceDict[clsName]?.obj)
            }
            guard let registration = box else { continue }

            var serviceObj = existingInst
            let cls = registration.cls

            if serviceObj == nil
                && (cls.instancesRespond(to: sel) || cls.responds(to: sel))
                && registration.autoInit {
                serviceObj = Mediator._service(name: registration.protocolName,
                                               priority: registration.priority,
                                               needProxyWrap: false)
            } else if let inst = serviceObj,
                      !inst.responds(to: sel),
                      cls.instancesRespond(to: sel) {
                serviceObj = cls
            }

            if let obj = serviceObj { results.append(obj) }
        }
        return results
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Sources/Classes/Swift/Public/Mediator.swift
git commit -m "feat: add Mediator.swift Part 3 - event system, dispatch query interface"
```

---

## Task 14: Mediator+Dispatch.m（ObjC Category — 变参注册 + dispatch）

**Files:**
- Create: `Sources/Classes/ObjC/Private/Mediator+Dispatch.h`
- Create: `Sources/Classes/ObjC/Private/Mediator+Dispatch.m`

- [ ] **Step 1: 创建 Mediator+Dispatch.h**

```objc
// Sources/Classes/ObjC/Private/Mediator+Dispatch.h
#import <Foundation/Foundation.h>
// ZDMOneForAll 由 Swift 生成头文件提供
// ObjC Category 扩展 nil-terminated 变参接口

@protocol ZDMCommonProtocol;
@class ZDMContext;

NS_ASSUME_NONNULL_BEGIN

@interface ZDMOneForAll (Dispatch)

#pragma mark - Register Event

+ (void)registerResponder:(Protocol *)serviceProtocol
                 priority:(NSInteger)priority
                  eventId:(NSString *)eventId, ...;

+ (void)registerResponder:(Protocol *)serviceProtocol
                 priority:(NSInteger)priority
                selectors:(SEL)selector, ...;

#pragma mark - Dispatch

+ (NSArray *)dispatchWithProtocol:(Protocol *)protocol
                       selAndArgs:(SEL)selector, ...;

+ (NSArray *)dispatchWithEventId:(NSString *)eventId
                      selAndArgs:(SEL)selector, ...;

+ (NSArray *)dispatchWithEventSelAndArgs:(SEL)selector, ...;

+ (NSArray *)dispatchWithSELAndArgs:(SEL)selector, ...;

@end

NS_ASSUME_NONNULL_END
```

- [ ] **Step 2: 创建 Mediator+Dispatch.m**

```objc
// Sources/Classes/ObjC/Private/Mediator+Dispatch.m
#import "Mediator+Dispatch.h"
#import "ZDMediator-Swift.h"   // SPM 混编自动生成，包含 Swift 定义的方法
#import "ZDMInvocation.h"

@implementation ZDMOneForAll (Dispatch)

#pragma mark - Register Event

+ (void)registerResponder:(Protocol *)serviceProtocol
                 priority:(NSInteger)priority
                  eventId:(NSString *)eventId, ... {
    if (!serviceProtocol) return;
    NSMutableArray<NSString *> *eventIds = [NSMutableArray array];
    va_list args;
    va_start(args, eventId);
    NSString *value = eventId;
    while (value) {
        [eventIds addObject:value];
        value = va_arg(args, NSString *);
    }
    va_end(args);
    [[self shared] _registerResponderForProtocol:serviceProtocol priority:priority eventIds:eventIds];
}

+ (void)registerResponder:(Protocol *)serviceProtocol
                 priority:(NSInteger)priority
                selectors:(SEL)selector, ... {
    if (!serviceProtocol) return;
    NSMutableArray<NSString *> *selectorNames = [NSMutableArray array];
    va_list args;
    va_start(args, selector);
    SEL value = selector;
    while (value) {
        [selectorNames addObject:NSStringFromSelector(value)];
        value = va_arg(args, SEL);
    }
    va_end(args);
    [[self shared] _registerResponderForProtocol:serviceProtocol priority:priority selectorNames:selectorNames];
}

#pragma mark - Dispatch
// Option B：ObjC 持有完整 dispatch 循环，Swift 提供有序实例列表
// va_list 在每次循环内独立声明 + va_start/va_end（ARM64 ABI 要求）

+ (NSArray *)dispatchWithProtocol:(Protocol *)protocol
                       selAndArgs:(SEL)selector, ... {
    if (!protocol || !selector) return @[];
    NSArray *targets = [[self shared] _serviceInstancesForProtocol:protocol];
    NSMutableArray *results = [NSMutableArray array];
    for (id target in targets) {
        va_list args;
        va_start(args, selector);
        id res = [ZDMInvocation target:target invokeSelector:selector args:args];
        va_end(args);
        if (res) [results addObject:res];
    }
    return results.copy;
}

+ (NSArray *)dispatchWithEventId:(NSString *)eventId
                      selAndArgs:(SEL)selector, ... {
    if (!eventId || !selector) return @[];
    NSArray *targets = [[self shared] _serviceInstancesForEventId:eventId];
    NSMutableArray *results = [NSMutableArray array];
    for (id target in targets) {
        va_list args;
        va_start(args, selector);
        id res = [ZDMInvocation target:target invokeSelector:selector args:args];
        va_end(args);
        if (res) [results addObject:res];
    }
    return results.copy;
}

+ (NSArray *)dispatchWithEventSelAndArgs:(SEL)selector, ... {
    if (!selector) return @[];
    NSString *selName = NSStringFromSelector(selector);
    NSArray *targets = [[self shared] _serviceInstancesForSelectorName:selName];
    NSMutableArray *results = [NSMutableArray array];
    for (id target in targets) {
        va_list args;
        va_start(args, selector);
        id res = [ZDMInvocation target:target invokeSelector:selector args:args];
        va_end(args);
        if (res) [results addObject:res];
    }
    return results.copy;
}

+ (NSArray *)dispatchWithSELAndArgs:(SEL)selector, ... {
    if (!selector) return @[];
    NSString *selName = NSStringFromSelector(selector);
    NSArray *targets = [[self shared] _allServiceInstancesRespondingToSelectorName:selName];
    NSMutableArray *results = [NSMutableArray array];
    for (id target in targets) {
        va_list args;
        va_start(args, selector);
        id res = [ZDMInvocation target:target invokeSelector:selector args:args];
        va_end(args);
        if (res) [results addObject:res];
    }
    return results.copy;
}

@end
```

- [ ] **Step 3: Commit**

```bash
git add Sources/Classes/ObjC/Private/Mediator+Dispatch.h \
        Sources/Classes/ObjC/Private/Mediator+Dispatch.m
git commit -m "feat: add Mediator+Dispatch.m ObjC Category (variadic register + dispatch, Option B)"
```

---

## Task 15: 更新 ZDMediator.h（Umbrella Header）

**Files:**
- Modify: `Sources/Classes/ObjC/Public/ZDMediator.h`

- [ ] **Step 1: 更新 ZDMediator.h**

将 `ZDMediator.h` 替换为（移除已删除 ObjC 文件的 import，Swift 类型通过模块自动可见）：

```objc
//  ZDMediator.h
//  ZDMediator 0.5.0
//  核心 ObjC 类型通过此头文件暴露；Swift 类型（Mediator、MediatorContext 等）
//  通过编译器自动生成的模块接口暴露，无需手动 import。

#ifndef ZDMediator_h
#define ZDMediator_h

#import "ZDMediatorDefine.h"
#import "ZDMProxy.h"
#import "ZDMBroadcastProxy.h"

// dispatch + registerResponder 变参接口
#import "Mediator+Dispatch.h"

// ObjC 调用宏（ZDMGetService 系列）定义在 ZDMediatorDefine.h 中
// Swift 类型（ZDMOneForAll / ZDMContext 等）由编译器通过 @objc(ZDMOneForAll) 暴露

#endif /* ZDMediator_h */
```

> **SPM 使用说明：** ObjC 代码 `@import ZDMediator` 后，所有 Swift 导出的 `@objc` 类（`ZDMOneForAll`、`ZDMContext` 等）自动可用，无需在此文件显式 import。

- [ ] **Step 2: Commit**

```bash
git add Sources/Classes/ObjC/Public/ZDMediator.h
git commit -m "feat: update ZDMediator.h umbrella - remove deleted ObjC imports, note Swift types auto-exposed"
```

---

## Task 16: 更新 ZDMediator.podspec

**Files:**
- Modify: `ZDMediator.podspec`

- [ ] **Step 1: 更新 podspec**

将 podspec 版本和 source_files 更新：

```ruby
Pod::Spec.new do |s|
  s.name             = 'ZDMediator'
  s.version          = '0.5.0'
  s.summary          = '模块通信中间件'
  s.description      = <<-DESC
    用于模块间通信的中间件，支持自动注册、手动注册、强弱引用、实例方法、类方法调用
  DESC
  s.homepage         = 'https://github.com/faimin/ZDMediator'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Zero.D.Saber' => 'fuxianchao@gmail.com' }
  s.source           = { :git => 'https://github.com/faimin/ZDMediator.git', :tag => s.version.to_s }
  s.prefix_header_file = false
  s.module_name = s.name
  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '14.0'

  s.subspec 'Tools' do |ss|
    ss.source_files = 'Sources/Classes/ObjC/Tools/*.{h,m}',
                      'Sources/Classes/Swift/Tools/*.swift'
  end

  s.subspec 'Mediator' do |ss|
    ss.dependency "#{s.name}/Tools"
    ss.source_files = 'Sources/Classes/ObjC/**/*.{h,m}',
                      'Sources/Classes/Swift/**/*.swift'
    ss.public_header_files = 'Sources/Classes/ObjC/Public/*.h',
                             'Sources/Classes/ObjC/Private/Mediator+Dispatch.h'
    ss.project_header_files = 'Sources/Classes/ObjC/Private/Mediator+Dispatch.h'
    ss.resource_bundles = {
      "#{s.name}_Privacy" => ['Sources/Resource/PrivacyInfo.xcprivacy']
    }
    ss.pod_target_xcconfig = {
      'DEFINES_MODULE'    => 'YES',
      'OTHER_SWIFT_FLAGS' => '-enable-experimental-feature SymbolLinkageMarkers'
    }
  end

  s.subspec 'EnableAssert' do |ss|
    ss.dependency "#{s.name}/Mediator"
    ss.pod_target_xcconfig = {
      'GCC_PREPROCESSOR_DEFINITIONS' => 'ENABLE_ASSERT=1',
      'OTHER_SWIFT_FLAGS' => '-enable-experimental-feature SymbolLinkageMarkers'
    }
  end

  s.subspec 'All' do |ss|
    ss.dependency 'ZDMediator/Mediator'
    ss.dependency 'ZDMediator/EnableAssert'
  end

  s.default_subspec = 'Mediator'
end
```

- [ ] **Step 2: Commit**

```bash
git add ZDMediator.podspec
git commit -m "build: update podspec to 0.5.0 - Swift source files, new paths, SymbolLinkageMarkers flag"
```

---

## Task 17: 删除旧 ObjC 文件

**Files:**
- Delete: 所有原有 ObjC 实现文件（已迁移至 Swift）

- [ ] **Step 1: 删除已被 Swift 替代的 ObjC 文件**

```bash
cd /Users/Zero_D_Saber/Documents/Github/ZDMediator
# Public
git rm Sources/Classes/Public/ZDMOneForAll.h
git rm Sources/Classes/Public/ZDMOneForAll.m
git rm Sources/Classes/Public/ZDMContext.h
git rm Sources/Classes/Public/ZDMContext.m
git rm Sources/Classes/Public/ZDMCommonProtocol.h
# Private
git rm Sources/Classes/Private/ZDMServiceBox.h
git rm Sources/Classes/Private/ZDMServiceBox.m
git rm Sources/Classes/Private/ZDMServiceItem.h
git rm Sources/Classes/Private/ZDMServiceItem.m
git rm Sources/Classes/Private/ZDMEventResponder.h
git rm Sources/Classes/Private/ZDMEventResponder.m
git rm Sources/Classes/Private/ZDMLock.h
git rm Sources/Classes/Private/ZDMLock.m
git rm Sources/Classes/Private/ZDMOneForAll+Private.h
# Tools
git rm Sources/Classes/Tools/NSObject+ZDMOnDealloc.h
git rm Sources/Classes/Tools/NSObject+ZDMOnDealloc.m
# 清理空目录
rmdir Sources/Classes/Public Sources/Classes/Private Sources/Classes/Tools 2>/dev/null || true
```

- [ ] **Step 2: 验证 Sources/Classes 结构**

```bash
find Sources/Classes -type f | sort
```

Expected: 仅包含 `Swift/` 和 `ObjC/` 两个子树下的文件

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "refactor: remove ObjC files replaced by Swift (ZDMOneForAll, ZDMContext, ZDMServiceBox, etc.)"
```

---

## Task 18: SPM 构建验证与测试

**Files:**
- Modify: `Tests/ZDMediatorTests/ZDMediatorTests.swift`（添加基础 Swift 测试）

- [ ] **Step 1: 尝试 SPM 构建**

```bash
cd /Users/Zero_D_Saber/Documents/Github/ZDMediator
swift build 2>&1
```

Expected: `Build complete!`（若有编译错误，根据错误信息修复后继续）

常见问题处理：
- **`ZDMCommonCallback` 未找到**：确认 `ZDMediatorDefine.h` 在 `publicHeadersPath` 内，且 `MediatorServiceProtocol.swift` 能通过模块导入访问
- **`ZDMediator-Swift.h` 未找到**：SPM 混编中此头文件由编译器自动注入，无需手动创建；`#import "ZDMediator-Swift.h"` 的路径由编译器处理
- **`ZDMBroadcastProxy` 未找到**：确认 `ZDMBroadcastProxy.h` 在 `publicHeadersPath`，且 Swift 端通过模块可见
- **`SectionEntry` section name**：已直接使用字面量 `"__ZDMKV_OFA"`，避免跨语言 C 宏依赖

- [ ] **Step 2: 添加 Swift 单元测试**

将 `Tests/ZDMediatorTests/ZDMediatorTests.swift` 替换为：

```swift
import XCTest
import ObjectiveC
@testable import ZDMediator

// 测试用协议和类（在测试 target 内部定义）
@objc protocol TestServiceProtocol: NSObjectProtocol {
    @objc optional func testMethod() -> String
}

@objc class TestServiceImpl: NSObject, TestServiceProtocol {
    func testMethod() -> String { "hello" }
}

// Swift protocol metatype 无法直接转为 ObjC Protocol *，必须用 objc_getProtocol
private func testProto() -> Protocol {
    guard let p = objc_getProtocol("TestServiceProtocol") else {
        fatalError("TestServiceProtocol not registered with ObjC runtime")
    }
    return p
}

final class ZDMediatorTests: XCTestCase {

    override func setUp() {
        super.setUp()
    }

    func testManualRegisterAndGet() {
        let impl = TestServiceImpl()
        Mediator.manualRegisterService(testProto(), implementer: impl)
        let retrieved = Mediator.service(testProto(), priority: 0)
        // 通过 ZDMProxy 包装返回，验证转发能力
        XCTAssertNotNil(retrieved)
    }

    func testWeakStoreCleansUp() {
        var impl: TestServiceImpl? = TestServiceImpl()
        Mediator.manualRegisterService(
            testProto(),
            priority: 999,
            implementer: impl!,
            weakStore: true
        )
        impl = nil  // 释放弱引用

        let expectation = self.expectation(description: "weak cleanup")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let retrieved = Mediator.serviceWithName(
                "TestServiceProtocol",
                priority: 999,
                onlyFromCache: true
            )
            XCTAssertNil(retrieved)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 2)
    }

    func testZDMLock() {
        let lock = ZDMLock()
        var counter = 0
        let group = DispatchGroup()
        for _ in 0..<100 {
            group.enter()
            DispatchQueue.global().async {
                lock.withLock { counter += 1 }
                group.leave()
            }
        }
        group.wait()
        XCTAssertEqual(counter, 100)
    }

    func testEventResponderHashableContract() {
        let a = EventResponder(serviceName: "A", priority: 10)
        let b = EventResponder(serviceName: "A", priority: 20)
        // 相等的两个值 hash 必须相同（Hashable 契约）
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    func testSectionEntryLayout() {
        // 确认 SectionEntry 内存布局与 ZDMMachoKVEntry 一致（24 bytes）
        XCTAssertEqual(MemoryLayout<SectionEntry>.size, 24)
        XCTAssertEqual(MemoryLayout<SectionEntry>.stride, 24)
        XCTAssertEqual(MemoryLayout<SectionEntry>.alignment, 8)
    }
}
```

- [ ] **Step 3: 运行 SPM 测试**

```bash
cd /Users/Zero_D_Saber/Documents/Github/ZDMediator
swift test 2>&1
```

Expected: `Test Suite 'All tests' passed` 或所有 ZDMediatorTests 测试通过

- [ ] **Step 4: Commit 测试文件**

```bash
git add Tests/ZDMediatorTests/ZDMediatorTests.swift
git commit -m "test: add Swift unit tests for Mediator, ZDMLock, EventResponder, SectionEntry layout"
```

---

## Task 19: Example App 测试验证（ObjC 调用方零改动验证）

- [ ] **Step 1: 打开 Example App 并尝试构建**

```bash
cd /Users/Zero_D_Saber/Documents/Github/ZDMediator/Example
pod install 2>&1 | tail -5
xcodebuild -workspace ZDMediator.xcworkspace \
           -scheme ZDMediator-Example \
           -destination 'platform=iOS Simulator,name=iPhone 16' \
           build 2>&1 | tail -20
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 2: 运行 Example App 测试（ObjC 测试集）**

```bash
xcodebuild test \
  -workspace ZDMediator.xcworkspace \
  -scheme ZDMediator-Example \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  2>&1 | grep -E "(Test Suite|PASS|FAIL|error:)"
```

Expected: 所有 `ZDAllTests` 和 `ZDDispatchTest` 测试通过

- [ ] **Step 3: 最终 Commit**

```bash
git add -A
git commit -m "feat: ZDMediator 0.5.0 Swift rewrite complete - all ObjC tests passing"
```

---

## 常见问题与修复指导

### Q1: `ZDMediator-Swift.h` 在 Mediator+Dispatch.m 中找不到
SPM 混编中，`#import "ZDMediator-Swift.h"` 由编译器自动处理（无需手动创建文件）。若报错，检查：
1. `Mediator.swift` 中的方法是否标记为 `@objc public`
2. `cSettings.headerSearchPath` 是否覆盖了 `Classes/ObjC/Private`

### Q2: `ZDMCommonCallback` 在 Swift 中找不到
`ZDMCommonCallback` 定义在 `ZDMediatorDefine.h`（在 `publicHeadersPath` 内），SPM 混编时自动桥接。若 `MediatorServiceProtocol.swift` 报错找不到此类型，在文件顶部加：
```swift
// ZDMCommonCallback 由 ObjC 头文件桥接，此处用 AnyObject 代替类型标注
typealias ZDMCommonCallback = @convention(block) () -> AnyObject?
```

### Q3: Swift 严格并发（`nonisolated` 警告）
Mediator 的所有状态通过 `ZDMLock` 手动保护，标记了 `@unchecked Sendable`。若出现新的并发警告，在具体方法上加 `nonisolated` 或 `@preconcurrency` 修饰。

### Q4: OrderedSet 编译错误
若 ReerKit 的 `OrderedSet` 是 `public`，在内部文件中直接可用。若有访问级别冲突，在文件顶部加 `internal typealias OrderedSet<T: Hashable> = ...`。

### Q5: `_registerResponderForProtocol:priority:eventIds:` Swift 方法名在 ObjC 中找不到
Swift 的 `@objc` 方法名由编译器生成。检查 `ZDMediator-Swift.h`（构建后在 DerivedData 中）确认实际 ObjC 方法签名，据此调整 `.m` 文件中的调用。
