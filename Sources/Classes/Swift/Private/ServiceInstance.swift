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
		if let disposable = old,
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
