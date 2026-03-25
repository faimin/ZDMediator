// Sources/Classes/Swift/Public/MediatorContext.swift
import Foundation

@objc(ZDMContext)
public final class MediatorContext: NSObject {
    @objc public var launchOptions: [AnyHashable: Any]?
    @objc public var extraObj: AnyObject?
}
