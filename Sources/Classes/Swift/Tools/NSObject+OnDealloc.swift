// Sources/Classes/Swift/Tools/NSObject+OnDealloc.swift
import Foundation
import ObjectiveC

private final class DeallocExecutor: NSObject {
    let block: () -> Void
    init(_ block: @escaping () -> Void) { self.block = block }
    deinit { block() }
}

nonisolated(unsafe) private var deallocKey: UInt8 = 0

extension NSObject {
    /// 注册一个 block，在 self 被释放时执行
    /// Breaking Change (0.5.0): block 从 `(id) -> Void` 简化为 `() -> Void`
    /// - Note: This method is not thread-safe. Callers should ensure `zdm_onDealloc` is
    ///   called from a single thread per object instance (typically at initialization time).
    @objc public func zdm_onDealloc(_ block: @escaping () -> Void) {
        var executors = objc_getAssociatedObject(self, &deallocKey) as? [DeallocExecutor] ?? []
        executors.append(DeallocExecutor(block))
        objc_setAssociatedObject(self, &deallocKey, executors, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}
