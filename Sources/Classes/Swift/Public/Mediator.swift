// Sources/Classes/Swift/Public/Mediator.swift
import Foundation
import ObjectiveC
#if canImport(ZDMediatorObjC)
import ZDMediatorObjC
#endif

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

    // ZDMBroadcastProxy 实例（NSProxy 子类，用 alloc 不用 init）
    // ZDMBroadcastProxy.h 在 publicHeadersPath 内，Swift 可直接引用
    // 内部存储属性，供 _updateProxyTargets 和 proxy 使用，避免循环引用
    private var _proxy: AnyObject?
    @objc public var proxy: AnyObject {
        lock.withLock {
            if _proxy == nil {
                _proxy = ZDMBroadcastProxy.alloc()
            }
            return _proxy!
        }
    }

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
				let existing: AnyClass? = registerInfoDict[key]?.cls
                if let existing, NSStringFromClass(existing) != NSStringFromClass(registration.cls) {
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

        // Note: Proxy target update is intentionally best-effort and called outside the lock.
        // The proxy may briefly reflect a slightly stale snapshot if concurrent registrations occur,
        // but correctness of service lookup is unaffected (that path re-acquires the lock).
        Mediator._updateProxyTargets()
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

    /// 不包装 ZDMProxy，直接返回原始实例（供 ZDMBroadcastProxy 内部使用，避免强引用导致弱引用对象无法释放）
    @objc public static func serviceInstanceWithName(_ name: String, priority: Int) -> AnyObject? {
        _service(name: name, priority: priority, needProxyWrap: false, onlyFromCache: false)
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
        // 先按 protocol-name 查找；若未找到则尝试 class-name 反查（供 ZDMBroadcastProxy 使用）
        var registration = shared.lock.withLock { shared.registerInfoDict[key] }
        if registration == nil {
            // name 可能是 class name，通过 registerClassDict 反查 protocol key
            registration = shared.lock.withLock {
                guard let keySet = shared.registerClassDict[name], !keySet.isEmpty else { return nil }
                // 优先匹配指定 priority，否则取任意一个
                let matchedKey = keySet.first(where: { $0.hasSuffix("--->\(effectivePriority)") }) ?? keySet.first!
                return shared.registerInfoDict[matchedKey]
            }
        }
        guard let registration else {
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
        // 注：ZDMProxy 继承自 NSProxy（而非 NSObject），不能用 NSObject.Type 转换
        if needProxyWrap,
           let proxyClass = NSClassFromString("ZDMProxy") {
            // 等效于 [ZDMProxy proxyWithTarget:instance]
            let proxy = (proxyClass as AnyObject).perform(
                NSSelectorFromString("proxyWithTarget:"),
                with: instance
            )?.takeUnretainedValue()

            // 设置 fixme 回调：当发现协议并非全类方法时，自动修正并创建实例
			if let proxy = proxy,
               proxy.responds(to: NSSelectorFromString("fixmeWithCallback:")) {
                let fixme: @convention(block) () -> AnyObject? = { [weak registration] in
                    guard let reg = registration else { return nil }
                    shared.lock.withLock { reg.isAllClassMethods = false }
                    return shared._createInstance(reg)
                }
                _ = proxy.perform(
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
		let cls: AnyClass = registration.cls
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
            instance = (cls as AnyObject).perform(NSSelectorFromString("zdm_createInstance:"), with: ctx)?
                .takeUnretainedValue() as AnyObject?
        }
        // 4. 默认 alloc（先存再 init，防循环依赖）
        // 注：AnyClass 在 Swift 中没有 .alloc()，必须通过 ObjC 消息转发
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

        // Note: best-effort proxy update after lock release — see _store for rationale.
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
        // 调用 ZDMBroadcastProxy.replaceTargetSet:（直接访问内部存储，避免触发 proxy 初始化循环）
        _ = shared.proxy.perform(
            NSSelectorFromString("replaceTargetSet:"),
            with: clsSet
        )
    }

    // proxyForBroadcast: 兼容旧 API，等同于 proxy
    @objc public var proxyForBroadcast: AnyObject? {
        proxy
    }
}

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
			let cls: AnyClass = registration.cls

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
