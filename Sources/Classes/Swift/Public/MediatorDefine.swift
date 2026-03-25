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
