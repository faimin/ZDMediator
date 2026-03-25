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
