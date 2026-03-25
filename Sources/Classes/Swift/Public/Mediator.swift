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

// MARK: - Stubs（implemented in later tasks）

extension Mediator {

    /// Implemented in Part 2 (service lookup)
    @objc public static func serviceWithName(_ name: String, priority: Int) -> AnyObject? {
        // Part 2 will provide the full implementation
        return nil
    }

    /// Implemented in Part 3 (remove service)
    @discardableResult
    @objc public static func removeService(
        _ serviceProtocol: Protocol,
        priority: Int,
        autoInitAgain: Bool
    ) -> Bool {
        // Part 3 will provide the full implementation
        return false
    }

    /// Implemented in Part 4 (proxy targets update)
    func _updateProxyTargets() {
        // Part 4 will provide the full implementation
    }
}
