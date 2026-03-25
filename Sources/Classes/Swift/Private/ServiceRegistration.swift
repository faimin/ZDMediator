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
