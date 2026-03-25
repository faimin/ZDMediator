// Sources/Classes/Swift/Private/ZDMLock.swift
import Foundation

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
